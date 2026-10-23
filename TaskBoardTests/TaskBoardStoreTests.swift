import Foundation
import Testing
@testable import TaskBoard

actor MockTodoService: TodoService {
    var todos: [Todo]
    var fetchError: (any Error)?
    private(set) var completionUpdates: [(id: Int, completed: Bool)] = []
    private(set) var createdTitles: [String] = []

    init(todos: [Todo] = [], fetchError: (any Error)? = nil) {
        self.todos = todos
        self.fetchError = fetchError
    }

    func fetchTodos(userID: Int) async throws -> [Todo] {
        if let fetchError { throw fetchError }
        return todos
    }

    func setCompleted(_ completed: Bool, todoID: Int) async throws {
        completionUpdates.append((todoID, completed))
    }

    func createTodo(title: String, userID: Int) async throws {
        createdTitles.append(title)
    }
}

@MainActor
struct TaskBoardStoreTests {
    /// Ids 1–6, only id 2 completed: 3 and 6 get seeded into Doing.
    private let sample = (1...6).map { Todo(id: $0, userId: 1, title: "Task \($0)", completed: $0 == 2) }

    private func loadedStore() async -> (TaskBoardStore, MockTodoService) {
        let service = MockTodoService(todos: sample)
        let store = TaskBoardStore(service: service)
        await store.load()
        return (store, service)
    }

    private func ids(_ store: TaskBoardStore, _ status: TaskStatus) -> [String] {
        store.tasks(in: status).map(\.id)
    }

    @Test func loadSplitsTasksIntoColumns() async {
        let (store, _) = await loadedStore()
        #expect(store.phase == .ready)
        #expect(ids(store, .todo) == ["1", "4", "5"])
        #expect(ids(store, .doing) == ["3", "6"])
        #expect(ids(store, .done) == ["2"])
        #expect(store.doneCount == 1)
    }

    @Test func loadFailureShowsConnectionMessage() async {
        let store = TaskBoardStore(service: MockTodoService(fetchError: URLError(.notConnectedToInternet)))
        await store.load()
        #expect(store.phase == .failed("Check your connection."))
    }

    @Test func moveBeforeCardReordersWithinColumn() async {
        let (store, _) = await loadedStore()
        store.move("5", to: .todo, before: "1")
        #expect(ids(store, .todo) == ["5", "1", "4"])
    }

    @Test func moveWithoutTargetAppendsToColumn() async {
        let (store, service) = await loadedStore()
        store.move("1", to: .doing)
        await store.waitForPendingRequest()
        #expect(ids(store, .doing) == ["3", "6", "1"])
        #expect(await service.completionUpdates.isEmpty)
    }

    @Test func movingIntoDoneSendsPatch() async {
        let (store, service) = await loadedStore()
        store.move("4", to: .done, before: "2")
        await store.waitForPendingRequest()
        #expect(ids(store, .done) == ["4", "2"])
        let updates = await service.completionUpdates
        #expect(updates.count == 1)
        #expect(updates.first?.id == 4 && updates.first?.completed == true)
    }

    @Test func toggleReopensToTopOfTodo() async {
        let (store, service) = await loadedStore()
        store.toggle("2")
        await store.waitForPendingRequest()
        #expect(ids(store, .todo) == ["2", "1", "4", "5"])
        #expect(await service.completionUpdates.first?.completed == false)
    }

    @Test func toggleCompletesToBottomOfDone() async {
        let (store, _) = await loadedStore()
        store.toggle("3")
        #expect(ids(store, .done) == ["2", "3"])
    }

    @Test func addPutsLocalTaskFirstAndNeverPatchesIt() async {
        let (store, service) = await loadedStore()
        store.add(title: "  Buy milk  ")
        await store.waitForPendingRequest()
        let added = store.tasks(in: .todo).first
        #expect(added?.title == "Buy milk")
        #expect(await service.createdTitles == ["Buy milk"])

        store.toggle(added!.id)
        await store.waitForPendingRequest()
        #expect(await service.completionUpdates.isEmpty)
    }

    @Test func addIgnoresBlankTitle() async {
        let (store, _) = await loadedStore()
        store.add(title: "   ")
        #expect(store.tasks.count == 6)
    }
}
