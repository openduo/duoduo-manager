import SwiftUI

struct JobsContentView: View {
    let jobs: [JobInfo]
    let isJobRunning: (String) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ODKicker(text: L10n.Dashboard.jobsTitle, tint: OpenDuo.textKicker)
                Text("  [\(jobs.count)]")
                    .font(.odMono(10))
                    .foregroundStyle(OpenDuo.textFaint)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Rectangle()
                .fill(OpenDuo.borderHairline)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if jobs.isEmpty {
                        Text("no jobs configured")
                            .font(.odMono(11))
                            .foregroundStyle(OpenDuo.textMuted)
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
        let cron = j.frontmatter?.cron ?? ""
        let isOnce = cron == "once" || cron.hasPrefix("@in ")
        let isKeepalive = cron == "keepalive"
        let result = j.state?.last_result ?? "idle"
        let runtime = j.frontmatter?.runtime ?? "claude"
        let color: Color = running ? OpenDuo.ok :
            (result == "failure" ? OpenDuo.alert :
             result == "success" ? OpenDuo.ok : OpenDuo.textMuted)

        return HStack(spacing: 0) {
            // Square state marker — the row's only colour
            ODStateTick(tint: color, size: 7)
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(j.id)
                        .font(.odMono(12, weight: .medium))
                        .foregroundStyle(OpenDuo.textPrimary)
                    if isOnce {
                        Text("[once]")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.cyan300)
                    } else if isKeepalive {
                        Text("[keepalive]")
                            .font(.odMono(9))
                            .foregroundStyle(OpenDuo.cyan200)
                    }
                    Text("[\(runtime)]")
                        .font(.odMono(9))
                        .foregroundStyle(OpenDuo.textMuted)
                }

                HStack(spacing: 0) {
                    if !cron.isEmpty {
                        Text("cron:\(cron)")
                            .foregroundStyle(OpenDuo.textMuted)
                        Text("  ·  ")
                            .foregroundStyle(OpenDuo.textFaint)
                    }
                    Text(running ? "running" : result)
                        .foregroundStyle(color)
                    if let lastRun = j.state?.last_run_at {
                        Text("  ·  last:\(SharedPresentationFormatting.timeAgo(lastRun))")
                            .foregroundStyle(OpenDuo.textMuted)
                    }
                    if let count = j.state?.run_count {
                        Text("  ·  runs:\(count)")
                            .foregroundStyle(OpenDuo.textMuted)
                    }
                    if let cwdRel = j.frontmatter?.cwd_rel {
                        Text("  ·  cwd:\(cwdRel)")
                            .foregroundStyle(OpenDuo.textMuted)
                    }
                }
                .font(.odMono(9))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OpenDuo.borderHairline).frame(height: 1).padding(.horizontal, 12)
        }
        .background(OpenDuo.surface)
    }

}
