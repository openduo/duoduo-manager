# Daemon LaunchAgent Migration

## Problem

duoduo daemon 通过 `detached:true` + `unref()` 启动，PPID 变为 1（launchd），脱离 DuoduoManager.app 的进程树。

macOS TCC 按进程链判断权限。daemon 及其子进程（agent session → claude-code → bash）访问 `~/Documents` 等受保护目录时，TCC 找不到有效的授权上下文，导致：

1. **反复弹窗**：每个新的 bash 子进程对每个受保护目录的首次访问都触发独立授权弹窗
2. **FDA 无效**：给 DuoduoManager.app 授 Full Disk Access 无济于事，因为 daemon (PPID=1) 不在 app 的进程树中
3. **adhoc signing**：DuoduoManager 是 adhoc 签名，每次编译 CDHash 变化，即使授权也不持久

### 根因分析

```
当前进程链：
launchd(1) → node daemon.js → claude-code → bash -c "ls ~/Documents"
                                  ↑
                            TCC 断裂点：PPID=1，不属于任何 app

DuoduoManager.app(PID X) ← 完全独立的进程，与 daemon 无 TCC 关联
```

#### 为什么弹窗显示 DuoduoManager.app 但给 FDA 却无效？

这是一个容易混淆的点。弹窗显示的名字和实际的授权机制是**两套独立的检查**：

1. **弹窗名字**来自环境变量 `__CFBundleIdentifier`：
   - DuoduoManager.app 通过 `Process()` 启动 `duoduo daemon start` 时，子进程继承了 `__CFBundleIdentifier=ai.openduo.manager`
   - 即使 daemon detach 后 PPID 变成 1，这个环境变量仍然保留
   - macOS TCC 弹窗时，读取 `__CFBundleIdentifier` 来决定显示哪个 app 的名字
   - 所以弹窗显示 "DuoduoManager.app 想要访问 Documents"

2. **FDA 授权传递**检查的是进程树链路：
   - FDA 要求 daemon 必须在 app 的进程树中（即 TCC 能通过 `ppid` 追溯到 app）
   - detach 后 daemon 的 PPID=1（launchd），不在 DuoduoManager.app 的进程树中
   - 用户点击"允许"，授权挂在 DuoduoManager.app 上，但对 daemon 无效
   - 下次访问新目录，又触发新的弹窗

这导致用户反复看到 "DuoduoManager.app 要求授权"，反复点击允许，但授权始终不生效。

#### detach 为什么有问题？

`duoduo daemon start` 内部使用 `child_process.spawn({ detached: true })` + `child.unref()`，让 daemon 脱离父进程独立运行。这是 Node.js daemon 的常见模式，但它与 macOS TCC 的进程树授权模型根本冲突：

- **App + detach**：daemon 脱离 app 进程树，TCC 继承链断，FDA 无法传递
- **App + 不 detach**：FDA 可以传递，但 app 退出 daemon 也得跟着退出，不适合长驻服务
- **LaunchAgent + 不 detach**：launchd 直接管理 `node daemon.js`，daemon 有独立 TCC 身份，不依赖任何父 app

## Solution

改用 macOS LaunchAgent 管理 daemon 生命周期。

```
改造后：
DuoduoManager.app → 写 plist → launchctl load → launchd 启动 daemon
                                                    ↓
                                    launchd(1) → node daemon.js → claude-code → bash
                                                                    ↑
                                                        daemon 有独立的 TCC identity
                                                        用户给 node 授一次 FDA 即可
```

### 为什么 LaunchAgent 能解决

- launchd 直接启动 `node daemon.js`，不经过 `duoduo daemon start` CLI
- daemon 不需要 detach，launchd 本身就是进程的管理者（PPID=1 是正常的）
- daemon 有独立、稳定的 TCC identity，不依赖 DuoduoManager.app 的进程链或签名
- 首次访问敏感目录时，系统弹窗显示 "node 想要访问 Documents"，用户授权一次即可
- 之后所有 daemon 子进程（claude、bash、find 等）自动继承权限，不再重复弹窗
- plist 内容固定，不受 app 重编译影响

## Implementation

### 1. 新增 LaunchAgentService

```swift
struct LaunchAgentService {
    static let label = "ai.openduo.manager.daemon"
    static let plistDir: String = "~/Library/LaunchAgents"
    static var plistPath: String { "\(plistDir)/\(label).plist" }

    // 生成 plist 内容
    static func generatePlist(environment: [String: String]) -> String

    // 安装 plist + launchctl load
    static func install(environment: [String: String]) throws

    // launchctl unload + 删除 plist
    static func uninstall() throws

    // 检查是否已安装
    static var isInstalled: Bool { get }
}
```

### 2. Plist 结构

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.openduo.manager.daemon</string>

    <key>ProgramArguments</key>
    <array>
        <string>{nodePath}</string>
        <string>{daemonJsPath}</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>ALADUO_DAEMON_URL</key>
        <string>http://127.0.0.1:20233</string>
        <key>ALADUO_LOG_LEVEL</key>
        <string>debug</string>
        <key>PATH</key>
        <string>{mergedPath}</string>
        <key>NPM_CONFIG_PREFIX</key>
        <string>{npmGlobalDir}</string>
        <!-- extraEnv from DaemonConfig -->
    </dict>

    <key>StandardOutPath</key>
    <string>{daemonSupervisorLog}</string>
    <key>StandardErrorPath</key>
    <string>{daemonSupervisorLog}</string>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
```

### 3. DaemonService 改动

```swift
// before:
func start()    → ShellService.run("duoduo", ["daemon", "start"])
func stop()     → ShellService.run("duoduo", ["daemon", "stop"])

// after:
func start()    → LaunchAgentService.install(environment: mergedEnv)
                  // 如果有旧 daemon 在跑，先 duoduo daemon stop 清理
func stop()     → LaunchAgentService.uninstall()
                  // 再用 duoduo daemon stop 清理残留 PID file
func restart()  → uninstall + install(newEnv)
func getStatus() → 不变，仍通过 HTTP /healthz + /rpc 检查
```

### 4. 关键路径值

| 值 | 来源 |
|---|---|
| `{nodePath}` | `NodeRuntime.bundledNodePath` 或系统 node |
| `{daemonJsPath}` | `NodeRuntime.duoduoPackageDir` + `/dist/release/daemon.js` |
| `{mergedPath}` | `NodeRuntime.environment["PATH"]` |
| `{npmGlobalDir}` | `NodeRuntime.npmGlobalDir` |
| `{daemonSupervisorLog}` | `~/.aladuo/run/daemon-supervisor.log` |

### 5. 升级/降级兼容

- 启动时检测：如果有残留的 PID file 但没有 plist → 说明是旧版启动的 → 先 `duoduo daemon stop` 清理，再走 LaunchAgent
- 首次安装 LaunchAgent 时：如果 daemon 已在运行 → 先 stop → 再 install → launchctl load

### 6. 环境变量更新

daemon 的 extraEnv（如 API keys）变化时，需要重新生成 plist：

```
DaemonConfig.envVars 变更 → stop → uninstall plist → install(new env) → daemon 重启
```

### 7. RunAtLoad 策略

`RunAtLoad: true` 确保 login 时 daemon 自动启动。但如果用户之前手动 stop 了，不应该自作主张重启。

方案：stop 时 `launchctl unload` + 删除 plist → 下次 login 不会自动加载。start 时重新写 plist + load。

## TCC 授权步骤（用户操作）

迁移后，用户需要：

1. 系统设置 → 隐私与安全性 → 完全磁盘访问权限
2. 添加 node 二进制：
   - Bundled 模式：`/Applications/DuoduoManager.app/Contents/Resources/node/bin/node`
   - System 模式：`/opt/homebrew/bin/node`（或实际 node 路径）
3. 重启 daemon

之后所有 agent session 的文件访问不再弹窗。

## Channel 生命周期不变

channel (feishu) 仍通过 `duoduo channel feishu start/stop` 管理，走 CLI 路径。channel 的 TCC 问题较小，因为 channel 本身不执行 shell 命令访问文件系统。

## 未解决的问题

- **node 的 FDA 授权范围较广**：给 node 授 FDA 意味着所有 node 进程都有完全磁盘访问权限。更好的方案是用 Apple Developer ID 签名 DuoduoManager.app，但这需要开发者账号。
- **bundled node 路径变化**：每次 app 更新如果 bundled node 版本变了，FDA 授权可能失效。需要用稳定路径或 symlink。
