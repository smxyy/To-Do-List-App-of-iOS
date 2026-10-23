import SwiftUI

@main
struct TaskBoardApp: App {
    @State private var store = TaskBoardStore()

    var body: some Scene {
        WindowGroup {
            BoardScreen()
                .environment(store)
        }
    }
}
