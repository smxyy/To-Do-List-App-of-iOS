import Foundation

struct Todo: Codable, Equatable, Sendable {
    let id: Int
    let userId: Int
    let title: String
    let completed: Bool
}

protocol TodoService: Sendable {
    func fetchTodos(userID: Int) async throws -> [Todo]
    func setCompleted(_ completed: Bool, todoID: Int) async throws
    func createTodo(title: String, userID: Int) async throws
}

enum APIError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(let code): "HTTP \(code)"
        }
    }
}

/// Free fake REST API. Writes are accepted but not persisted, so a reload resets the board.
struct JSONPlaceholderService: TodoService {
    var baseURL = URL(string: "https://jsonplaceholder.typicode.com")!
    var session: URLSession = .shared

    func fetchTodos(userID: Int) async throws -> [Todo] {
        let url = baseURL.appending(path: "todos").appending(queryItems: [URLQueryItem(name: "userId", value: String(userID))])
        let data = try await send(URLRequest(url: url))
        return try JSONDecoder().decode([Todo].self, from: data)
    }

    func setCompleted(_ completed: Bool, todoID: Int) async throws {
        var request = URLRequest(url: baseURL.appending(path: "todos/\(todoID)"))
        request.httpMethod = "PATCH"
        request.httpBody = try JSONEncoder().encode(["completed": completed])
        _ = try await send(request)
    }

    func createTodo(title: String, userID: Int) async throws {
        struct Body: Encodable {
            let title: String
            let completed: Bool
            let userId: Int
        }
        var request = URLRequest(url: baseURL.appending(path: "todos"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(Body(title: title, completed: false, userId: userID))
        _ = try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        return data
    }
}
