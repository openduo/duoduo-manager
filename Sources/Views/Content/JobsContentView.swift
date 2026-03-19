import SwiftUI

struct JobsContentView: View {
    let jobs: [JobInfo]
    let isJobRunning: (String) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("> ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.accent)
                Text("jobs")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DashboardTheme.text)
                Text("  [\(jobs.count)]")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DashboardTheme.textTertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(DashboardTheme.border)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if jobs.isEmpty {
                        Text("no jobs configured")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(DashboardTheme.textTertiary)
                            .padding(40)
                    } else {
                        ForEach(jobs) { job in
                            jobRow(job)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func jobRow(_ j: JobInfo) -> some View {
        let running = isJobRunning(j.id)
        let isOnce = j.frontmatter?.cron == "once"
        let result = j.state?.last_result ?? "idle"
        let color: Color = running ? DashboardTheme.emerald :
            (result == "failure" ? DashboardTheme.red :
             result == "success" ? DashboardTheme.blue : DashboardTheme.textTertiary)

        return HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(color)
                .frame(width: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(j.id)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DashboardTheme.text)
                    if isOnce {
                        Text("[once]")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(DashboardTheme.accent)
                    }
                }

                HStack(spacing: 0) {
                    if let cron = j.frontmatter?.cron {
                        Text("cron:\(cron)")
                            .foregroundStyle(DashboardTheme.textTertiary)
                        Text("  •  ")
                            .foregroundStyle(DashboardTheme.border)
                    }
                    Text(running ? "[running]" : "[\(result)]")
                        .foregroundStyle(color)
                    if let lastRun = j.state?.last_run_at {
                        Text("  •  last:\(DashboardTheme.timeAgo(lastRun))")
                            .foregroundStyle(DashboardTheme.textTertiary)
                    }
                    if let count = j.state?.run_count {
                        Text("  •  runs:\(count)")
                            .foregroundStyle(DashboardTheme.textTertiary)
                    }
                }
                .font(.system(size: 10, design: .monospaced))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Spacer()
        }
        .background(DashboardTheme.cardBackground)
    }

}
