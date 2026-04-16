import Foundation

extension AppStore {
    func setPopoverVisible(_ isVisible: Bool) {
        setSurface(.popover, visible: isVisible)
    }

    func setDashboardVisible(_ isVisible: Bool) {
        setSurface(.dashboard, visible: isVisible)
    }

    func shutdown() {
        visibleSurfaces.removeAll()
        prepareInteractiveSessionTask?.cancel()
        prepareInteractiveSessionTask = nil
        stopRuntimePolling()
        stopDashboardPollingTasks()
    }

    private func setSurface(_ surface: AppStoreSurface, visible: Bool) {
        if visible {
            visibleSurfaces.insert(surface)
            if surface == .popover {
                Task { [weak self] in
                    await self?.checkForUpdates(force: true)
                    self?.updateStatusBarIcon?()
                }
            }
        } else {
            visibleSurfaces.remove(surface)
        }
        reconcileVisibilityDrivenWork()
    }

    private func reconcileVisibilityDrivenWork() {
        let wantsRuntime = visibleSurfaces.contains(.popover)
        let wantsDashboard = !visibleSurfaces.isEmpty

        if wantsRuntime || wantsDashboard {
            prepareInteractiveSessionIfNeeded()
        }

        if wantsRuntime {
            startRuntimePollingIfNeeded()
        } else {
            stopRuntimePolling()
        }

        if wantsDashboard {
            startDashboardPollingTasksIfNeeded()
        } else {
            stopDashboardPollingTasks()
        }
    }

    private func prepareInteractiveSessionIfNeeded() {
        guard !hasPreparedInteractiveSession, prepareInteractiveSessionTask == nil else { return }

        prepareInteractiveSessionTask = Task { [weak self] in
            guard let self else { return }
            await self.ensureDuoduoInstalledIfNeeded()
            self.hasPreparedInteractiveSession = true
            self.prepareInteractiveSessionTask = nil
            await self.refreshVisibleContentNow()
        }
    }

    func refreshVisibleContentNow() async {
        if visibleSurfaces.contains(.popover) {
            await refreshRuntime()
        }
        if !visibleSurfaces.isEmpty {
            await fetchDashboardAll()
        }
        updateStatusBarIcon?()
    }

    private func startRuntimePollingIfNeeded() {
        guard runtimeRefreshTask == nil else { return }

        Task {
            await refreshRuntime()
            updateStatusBarIcon?()
        }

        runtimeRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.runtimeRefreshInterval ?? 30))
                guard !Task.isCancelled else { break }
                await self?.refreshRuntime()
            }
        }
    }

    private func stopRuntimePolling() {
        runtimeRefreshTask?.cancel()
        runtimeRefreshTask = nil
    }

    private func startDashboardPollingTasksIfNeeded() {
        if dashboardEventsTask == nil || dashboardStatusTask == nil {
            dashboardEventsTask?.cancel()
            dashboardStatusTask?.cancel()
            Task { await fetchDashboardAll() }

            dashboardEventsTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(self?.dashboardEventsInterval ?? 3))
                    guard !Task.isCancelled else { break }
                    await self?.fetchDashboardEvents()
                }
            }

            dashboardStatusTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(self?.dashboardStatusInterval ?? 5))
                    guard !Task.isCancelled else { break }
                    await self?.fetchDashboardStatus()
                }
            }
        }
    }

    private func stopDashboardPollingTasks() {
        dashboardEventsTask?.cancel()
        dashboardStatusTask?.cancel()
        dashboardEventsTask = nil
        dashboardStatusTask = nil
    }
}
