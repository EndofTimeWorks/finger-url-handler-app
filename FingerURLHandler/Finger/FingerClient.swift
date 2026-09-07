import Foundation
import Network

enum FingerClientError: LocalizedError {
    case invalidHost
    case invalidPort
    case invalidRequest
    case nonASCIIRequest
    case timedOut
    case responseTooLarge
    case connection(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Enter a host name or IP address."
        case .invalidPort:
            return "The port must be between 1 and 65535."
        case .invalidRequest:
            return "Finger requests may not contain CR or LF characters."
        case .nonASCIIRequest:
            return "Finger requests must be ASCII."
        case .timedOut:
            return "The Finger server did not respond before the 10-second timeout."
        case .responseTooLarge:
            return "The server returned more than 1 MiB, so the connection was stopped."
        case .connection(let message):
            return message
        }
    }
}

final class FingerClient {
    struct Request {
        let host: String
        let port: UInt16
        let request: String
        let verbose: Bool
    }

    private let queue = DispatchQueue(label: "works.endoftime.Finger.network")
    private let maximumResponseSize = 1_048_576
    private let timeout: TimeInterval = 10

    func query(_ request: Request, completion: @escaping (Result<String, Error>) -> Void) {
        let hostText = request.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostText.isEmpty,
              hostText.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            completion(.failure(FingerClientError.invalidHost))
            return
        }

        guard request.port > 0, let nwPort = NWEndpoint.Port(rawValue: request.port) else {
            completion(.failure(FingerClientError.invalidPort))
            return
        }

        guard !request.request.contains("\r"), !request.request.contains("\n") else {
            completion(.failure(FingerClientError.invalidRequest))
            return
        }

        let wireRequest = request.verbose
            ? (request.request.isEmpty ? "/W" : "/W \(request.request)")
            : request.request

        guard let queryData = "\(wireRequest)\r\n".data(using: .ascii) else {
            completion(.failure(FingerClientError.nonASCIIRequest))
            return
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(hostText),
            port: nwPort,
            using: .tcp
        )

        queue.async {
            var response = Data()
            var isFinished = false
            var timeoutItem: DispatchWorkItem?

            func finish(_ result: Result<String, Error>) {
                guard !isFinished else { return }
                isFinished = true
                timeoutItem?.cancel()
                connection.stateUpdateHandler = nil
                connection.cancel()
                DispatchQueue.main.async {
                    completion(result)
                }
            }

            func decode(_ data: Data) -> String {
                if let utf8 = String(data: data, encoding: .utf8) {
                    return utf8
                }
                if let latin1 = String(data: data, encoding: .isoLatin1) {
                    return latin1
                }
                return String(decoding: data, as: UTF8.self)
            }

            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, error in
                    if let data, !data.isEmpty {
                        response.append(data)
                        if response.count > self.maximumResponseSize {
                            finish(.failure(FingerClientError.responseTooLarge))
                            return
                        }
                    }

                    if let error {
                        finish(.failure(FingerClientError.connection(error.localizedDescription)))
                        return
                    }

                    if isComplete {
                        finish(.success(decode(response)))
                        return
                    }

                    receiveNext()
                }
            }

            let newTimeoutItem = DispatchWorkItem {
                finish(.failure(FingerClientError.timedOut))
            }
            timeoutItem = newTimeoutItem
            self.queue.asyncAfter(deadline: .now() + self.timeout, execute: newTimeoutItem)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: queryData, completion: .contentProcessed { error in
                        if let error {
                            finish(.failure(FingerClientError.connection(error.localizedDescription)))
                            return
                        }
                        receiveNext()
                    })
                case .failed(let error):
                    finish(.failure(FingerClientError.connection(error.localizedDescription)))
                case .cancelled:
                    if !isFinished {
                        finish(.failure(FingerClientError.connection("The connection was cancelled.")))
                    }
                default:
                    break
                }
            }

            connection.start(queue: self.queue)
        }
    }
}
