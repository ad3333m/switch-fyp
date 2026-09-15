import SwiftUI

struct AddonsSettingsView: View {
    @EnvironmentObject var addonManager: AddonManager
    @State private var urlText: String = ""
    @State private var errorMessage: String?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Add addon") {
                    TextField("https://example.com/manifest.json", text: $urlText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)

                    Button {
                        Task { await add() }
                    } label: {
                        if adding {
                            ProgressView()
                        } else {
                            Text("Add addon")
                        }
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || adding)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section("Installed addons (\(addonManager.addons.count))") {
                    if addonManager.addons.isEmpty {
                        Text("No addons installed yet.")
                            .foregroundColor(.gray)
                    }
                    ForEach(addonManager.addons) { addon in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(addon.manifest.name).bold()
                            Text(addon.manifestURL.absoluteString)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    .onDelete { addonManager.remove(at: $0) }
                }
            }
            .navigationTitle("Addons")
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
        }
    }

    private func add() async {
        errorMessage = nil
        adding = true
        defer { adding = false }
        do {
            try await addonManager.add(urlString: urlText)
            urlText = ""
        } catch {
            errorMessage = "Couldn't load that addon manifest. Check the URL and try again."
        }
    }
}
