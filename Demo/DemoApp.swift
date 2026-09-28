import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            SkillLockDemoView(viewModel: SkillLockDemoViewModel.sampleFleetScenario())
        }
    }
}
