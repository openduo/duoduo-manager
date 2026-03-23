import Foundation

struct DashboardRPCService: Sendable {
    let baseURL: String

    init(daemonURL: String) {
        self.baseURL = daemonURL
    }

    func systemStatus() async throws -> SystemStatus {
        try await call("system.status")
    }

    func usage() async throws -> UsageResponse {
        try await call("usage.get")
    }

    func jobList() async throws -> JobListResponse {
        try await call("job.list")
    }

    func spineTail(afterId: String? = nil, limit: Int = 200) async throws -> SpineTailResponse {
        var params: [String: Any] = ["limit": limit]
        if let afterId { params["after_id"] = afterId }
        return try await call("spine.tail", params: params)
    }

    // MARK: - Private

    private func call<T: Decodable>(_ method: String, params: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(baseURL)/rpc") else {
            throw RPCClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        var body: [String: Any] = ["jsonrpc": "2.0", "id": Int(Date().timeIntervalSince1970 * 1000), "method": method]
        if let params { body["params"] = params }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RPCClientError.httpError
        }

        let rpc = try JSONDecoder().decode(RPCResponse<T>.self, from: data)
        if let error = rpc.error {
            throw RPCClientError.rpcError(error.message)
        }
        guard let result = rpc.result else {
            throw RPCClientError.noResult
        }
        return result
    }
}

enum RPCClientError: LocalizedError {
    case invalidURL
    case httpError
    case rpcError(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid RPC URL"
        case .httpError: "HTTP request failed"
        case .rpcError(let msg): "RPC error: \(msg)"
        case .noResult: "No result in RPC response"
        }
    }
}
