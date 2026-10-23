import Foundation

enum TaskStatus: String, CaseIterable, Identifiable, Sendable {
    case todo, doing, done

    var id: Self { self }

    var title: String {
        switch self {
        case .todo: "To do"
        case .doing: "Doing"
        case .done: "Done"
        }
    }
}

struct TaskItem: Identifiable, Equatable, Sendable {
    let id: String
    /// Server id. `nil` for tasks created in the app, since the API never actually stores them.
    let remoteID: Int?
    var title: String
    var status: TaskStatus
}
