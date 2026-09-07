import SwiftUI
import UIKit

@MainActor
final class FingerViewModel: ObservableObject {
    @Published var host = ""
    @Published var port = "79"
    @Published var request = ""
    @Published var verbose = false
    @Published var output = ""
    @Published var status = "Ready"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client = FingerClient()
    private var queryGeneration = 0

    var target: FingerTarget? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty,
              let portValue = UInt16(port),
              portValue > 0 else { return nil }
        return FingerTarget(host: trimmedHost, port: portValue, request: request, verbose: verbose)
    }

    var canonicalURLText: String {
        target?.canonicalURL?.absoluteString ?? ""
    }

    func run() {
        queryGeneration += 1
        let generation = queryGeneration
        errorMessage = nil
        output = ""

        guard let target else {
            errorMessage = "Enter a host and a valid port."
            status = "Invalid target"
            return
        }

        guard !target.request.contains("\r"), !target.request.contains("\n") else {
            errorMessage = FingerClientError.invalidRequest.localizedDescription
            status = "Invalid request"
            return
        }

        isLoading = true
        status = "Connecting to \(target.host):\(target.port)…"

        client.query(.init(
            host: target.host,
            port: target.port,
            request: target.request,
            verbose: target.verbose
        )) { [weak self] result in
            guard let self else { return }
            guard self.queryGeneration == generation else { return }
            self.isLoading = false
            switch result {
            case .success(let text):
                self.output = text.isEmpty ? "(empty response)" : text
                self.status = "Done"
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.status = "Failed"
            }
        }
    }

    func handle(url: URL) {
        do {
            let target = try FingerTarget(url: url)
            host = target.host
            port = String(target.port)
            request = target.request
            verbose = target.verbose
            run()
        } catch {
            queryGeneration += 1
            isLoading = false
            errorMessage = error.localizedDescription
            status = "Invalid Finger URL"
        }
    }

    func copyURL() {
        guard !canonicalURLText.isEmpty else { return }
        UIPasteboard.general.string = canonicalURLText
        status = "URL copied"
    }

    func copyOutput() {
        guard !output.isEmpty else { return }
        UIPasteboard.general.string = output
        status = "Response copied"
    }
}

struct ContentView: View {
    @ObservedObject var model: FingerViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case host, port, request
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    TextField("example.com", text: $model.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .host)

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("79", text: $model.port)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                            .focused($focusedField, equals: .port)
                    }

                    TextField("user (blank = list users)", text: $model.request)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .request)
                        .onSubmit { model.run() }

                    Toggle("Verbose (/W)", isOn: $model.verbose)

                    Button {
                        focusedField = nil
                        model.run()
                    } label: {
                        HStack {
                            if model.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(model.isLoading ? "Querying…" : "Finger")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(model.isLoading || model.target == nil)
                }

                if !model.canonicalURLText.isEmpty {
                    Section("URL") {
                        Text(model.canonicalURLText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)

                        Button("Copy Finger URL", systemImage: "doc.on.doc") {
                            model.copyURL()
                        }
                    }
                }

                Section("Response") {
                    if let error = model.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } else if model.output.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "terminal")
                                .font(.title2)
                            Text("No Response Yet")
                                .font(.headline)
                            Text("Enter a host or open a finger:// URL.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ScrollView(.horizontal) {
                            Text(model.output)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button("Copy Response", systemImage: "doc.on.doc") {
                            model.copyOutput()
                        }
                    }
                }

                Section {
                    LabeledContent("Status", value: model.status)
                } footer: {
                    Text("Finger is an old plaintext protocol. Queries and responses are not encrypted.")
                }
            }
            .navigationTitle("Finger")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }
}

#Preview {
    ContentView(model: FingerViewModel())
}
