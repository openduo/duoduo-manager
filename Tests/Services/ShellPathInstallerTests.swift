import XCTest
@testable import DuoduoManager

final class ShellPathInstallerTests: XCTestCase {
    private var tempHome: URL!

    override func setUpWithError() throws {
        tempHome = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
        ShellPathInstaller.homeDirectoryOverride = tempHome.path
    }

    override func tearDownWithError() throws {
        ShellPathInstaller.homeDirectoryOverride = nil
        if let tempHome {
            try? FileManager.default.removeItem(at: tempHome)
        }
    }

    func testInstallAndDetectInstalledAcrossLoginProfiles() throws {
        try ShellPathInstaller.install()

        XCTAssertEqual(ShellPathInstaller.detect(), .installed)
        XCTAssertTrue(try profileContents(".zprofile").contains(ShellPathInstaller.beginMarker))
        XCTAssertTrue(try profileContents(".bash_profile").contains(ShellPathInstaller.beginMarker))
    }

    func testDetectReturnsPartialWhenOnlyZshProfileContainsBlock() throws {
        try writeProfile(".zprofile", contents: ShellPathInstaller.managedBlock())

        XCTAssertEqual(ShellPathInstaller.detect(), .partiallyInstalled)
    }

    func testReinstallDoesNotDuplicateManagedBlock() throws {
        try ShellPathInstaller.install()
        try ShellPathInstaller.install()

        let zprofile = try profileContents(".zprofile")
        XCTAssertEqual(zprofile.components(separatedBy: ShellPathInstaller.beginMarker).count - 1, 1)
    }

    func testUninstallRemovesManagedBlockFromAllCandidates() throws {
        try ShellPathInstaller.install()
        try ShellPathInstaller.uninstall()

        XCTAssertEqual(ShellPathInstaller.detect(), .notInstalled)
        XCTAssertFalse(try profileContents(".zprofile").contains(ShellPathInstaller.beginMarker))
        XCTAssertFalse(try profileContents(".bash_profile").contains(ShellPathInstaller.beginMarker))
    }

    private func writeProfile(_ name: String, contents: String) throws {
        try contents.write(to: tempHome.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    private func profileContents(_ name: String) throws -> String {
        try String(contentsOf: tempHome.appendingPathComponent(name), encoding: .utf8)
    }
}
