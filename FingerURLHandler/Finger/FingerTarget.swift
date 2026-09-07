import Foundation

enum FingerTargetError: LocalizedError, Equatable {
    case wrongScheme
    case missingHost
    case invalidPort
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .wrongScheme:
            return "This app only handles finger:// URLs."
        case .missingHost:
            return "The Finger URL is missing a host."
        case .invalidPort:
            return "The port must be between 1 and 65535."
        case .invalidRequest:
            return "The request contains characters that Finger cannot safely send."
        }
    }
}

struct FingerTarget: Equatable {
    var host: String
    var port: UInt16 = 79
    var request: String = ""
    var verbose = false

    init(host: String, port: UInt16 = 79, request: String = "", verbose: Bool = false) {
        self.host = host
        self.port = port
        self.request = request
        self.verbose = verbose
    }

    init(url: URL) throws {
        guard url.scheme?.lowercased() == "finger" else {
            throw FingerTargetError.wrongScheme
        }

        let rawURL = url.absoluteString.lowercased()
        guard !rawURL.contains("%0d"), !rawURL.contains("%0a") else {
            throw FingerTargetError.invalidRequest
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let componentHost = components.host,
              !componentHost.isEmpty else {
            throw FingerTargetError.missingHost
        }

        // Foundation implementations can preserve IPv6 URI brackets in `host`.
        // Network.framework wants the literal address without them.
        let parsedHost: String
        if componentHost.hasPrefix("["), componentHost.hasSuffix("]") {
            parsedHost = String(componentHost.dropFirst().dropLast())
        } else {
            parsedHost = componentHost
        }

        let parsedPort = components.port ?? 79
        guard (1...65535).contains(parsedPort), let port = UInt16(exactly: parsedPort) else {
            throw FingerTargetError.invalidPort
        }

        var decodedRequest = ""
        if !components.percentEncodedPath.isEmpty && components.percentEncodedPath != "/" {
            let encoded = String(components.percentEncodedPath.dropFirst())
            decodedRequest = encoded.removingPercentEncoding ?? encoded
        } else if let encodedUser = components.percentEncodedUser, !encodedUser.isEmpty {
            decodedRequest = encodedUser.removingPercentEncoding ?? encodedUser
        }

        var verbose = false
        let upper = decodedRequest.uppercased()
        if upper == "/W" {
            verbose = true
            decodedRequest = ""
        } else if upper.hasPrefix("/W ") {
            verbose = true
            decodedRequest = String(decodedRequest.dropFirst(3))
        }

        // Convenience extension for hand-authored URLs such as
        // finger://example.com/alice?verbose=1
        if components.queryItems?.contains(where: {
            let name = $0.name.lowercased()
            let value = ($0.value ?? "1").lowercased()
            return (name == "w" || name == "verbose") && ["1", "true", "yes", "on"].contains(value)
        }) == true {
            verbose = true
        }

        let lowercasedRequest = decodedRequest.lowercased()
        guard !decodedRequest.contains("\r"),
              !decodedRequest.contains("\n"),
              !lowercasedRequest.contains("%0d"),
              !lowercasedRequest.contains("%0a") else {
            throw FingerTargetError.invalidRequest
        }

        self.init(host: parsedHost, port: port, request: decodedRequest, verbose: verbose)
    }

    var wireRequest: String {
        if verbose {
            return request.isEmpty ? "/W" : "/W \(request)"
        }
        return request
    }

    var canonicalURL: URL? {
        var authority = host
        if host.contains(":") && !host.hasPrefix("[") {
            authority = "[\(host)]"
        }
        if port != 79 {
            authority += ":\(port)"
        }

        guard !wireRequest.isEmpty else {
            return URL(string: "finger://\(authority)/")
        }

        var allowed = CharacterSet.alphanumerics
        allowed.formUnion(CharacterSet(charactersIn: "-._~"))
        guard let encoded = wireRequest.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "finger://\(authority)/\(encoded)")
    }
}
