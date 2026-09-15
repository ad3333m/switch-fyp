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
                        .padding(12)
                        .glassPill(cornerRadius: 12)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    Button {
                        Task { await add() }
                    } label: {
                        HStack {
                            Spacer()
                            if adding {
                                ProgressView().tint(.white)
                            } else {
                                Text("Add addon").font(.headline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .glassCapsule()
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || adding)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                Section("Installed addons (\(addonManager.addons.count))") {
                    if addonManager.addons.isEmpty {
                        Text("No addons installed yet.")
                            .foregroundColor(.gray)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(addonManager.addons) { addon in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(addon.manifest.name).bold().foregroundColor(.white)
                            Text(addon.manifestURL.absoluteString)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: 14)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { addonManager.remove(at: $0) }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Addons")
            .scrollContentBackground(.hidden)
            .background(AppBackground())
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
