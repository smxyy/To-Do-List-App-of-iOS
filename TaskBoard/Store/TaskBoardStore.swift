import Foundation
import Observation

@MainActor
@Observable
final class TaskBoardStore {
    enum Phase: Equatable {
        case loading
        case failed(String)
        case ready
    }

    /// All tasks in display order; each column shows the subset with its status.
    private(set) var tasks: [TaskItem] = []
    private(set) var phase: Phase = .loading
    let userID: Int

    private let service: any TodoService
    @ObservationIgnored private var lastRequest: Task<Void, Never>?

    init(userID: Int = 1, service: any TodoService = JSONPlaceholderService()) {
        self.userID = userID
        self.service = service
    }

    var doneCount: Int { tasks.count(where: { $0.status == .done }) }

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
    }

    func load() async {
        phase = .loading
        do {
            tasks = Self.board(from: try await service.fetchTodos(userID: userID))
            phase = .ready
        } catch is URLError {
            phase = .failed("Check your connection.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// The API only knows completed / not completed, so seed up to two open tasks into "Doing".
    static func board(from todos: [Todo]) -> [TaskItem] {
        var doing = 0
        return todos.map { todo in
            var status: TaskStatus = todo.completed ? .done : .todo
            if !todo.completed && doing < 2 && todo.id % 3 == 0 {
                status = .doing
                doing += 1
            }
            return TaskItem(id: String(todo.id), remoteID: todo.id, title: todo.title, status: status)
        }
    }

    /// Moves a task into `status`, placed just before `targetID`, or at the end of the column when `nil`.
    func move(_ id: String, to status: TaskStatus, before targetID: String? = nil) {
        guard targetID != id, let task = tasks.first(where: { $0.id == id }) else { return }
        var rest = tasks.filter { $0.id != id }
        var moved = task
        moved.status = status

        let position: Int
        if let targetID, let index = rest.firstIndex(where: { $0.id == targetID }) {
            position = index
        } else if let last = rest.lastIndex(where: { $0.status == status }) {
            position = last + 1
        } else {
            position = rest.count
        }
        rest.insert(moved, at: position)
        tasks = rest
        syncCompletion(of: moved, previous: task.status)
    }

    /// Completing sends a task to the bottom of Done; reopening puts it at the top of To do.
    func toggle(_ id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        if task.status == .done {
            move(id, to: .todo, before: tasks(in: .todo).first?.id)
        } else {
            move(id, to: .done)
        }
    }

    func add(title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        tasks.insert(TaskItem(id: "local-\(UUID().uuidString)", remoteID: nil, title: title, status: .todo), at: 0)
        let service = service, userID = userID
        lastRequest = Task { try? await service.createTodo(title: title, userID: userID) }
    }

    /// Lets tests wait for the fire-and-forget request started by the last change.
    func waitForPendingRequest() async {
        await lastRequest?.value
    }

    /// "Doing" is local only; the server just hears about moves into or out of Done.
    private func syncCompletion(of task: TaskItem, previous: TaskStatus) {
        let isDone = task.status == .done
        guard let remoteID = task.remoteID, (previous == .done) != isDone else { return }
        let service = service
        lastRequest = Task { try? await service.setCompleted(isDone, todoID: remoteID) }
    }
}
