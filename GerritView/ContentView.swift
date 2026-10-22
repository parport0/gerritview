import SwiftUI

let backgroundGradient = LinearGradient(
    colors: [Color.red, Color.yellow],
    startPoint: .top, endPoint: .bottom
)

struct hideScrollEdgeEffectModifier: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .scrollEdgeEffectHidden()
        } else {
            content
        }
    }
}
extension View {
    func hideScrollEdgeEffect() -> some View {
        self.modifier(hideScrollEdgeEffectModifier())
    }
}

struct ChangeRoute: Hashable {
    let changeId: String
}

struct ContentView: View {
    @State var settings = Settings()
    @State private var path = NavigationPath()

    private func handleGerritURL(_ url: URL) {
        let components = URLComponents(string: url.absoluteString)
        if components?.scheme == "gerritview" {
            if components?.host == "change" {
                path.append(ChangeRoute(changeId: String((components?.path ?? "").dropFirst())))
            } else if let userId = Int(components?.host ?? "") {
                // Navigate to the change list showing the changes
                // owned by the account behind the link.
                Task {
                    guard let account = try? await fetchAccount(
                        settings: settings, accountId: userId) else {
                        return
                    }
                    if let email = account.email {
                        settings.pendingSearch = "owner:" + email
                    } else if let username = account.username {
                        settings.pendingSearch = "owner:" + username
                    } else {
                        return
                    }
                    path = NavigationPath()
                }
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack {
                ChangeListView()
            }.onOpenURL { url in
                handleGerritURL(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: CommentTextViewRepresentable.linkTappedNotification)) { note in
                if let url = note.object as? URL {
                    handleGerritURL(url)
                }
            }
            .navigationDestination(for: ChangeRoute.self) { route in
                ChangePageView(changeId: route.changeId)
            }
            .toolbar {
                Group {
                    ToolbarItem(placement: .principal) {
                        Text("\(Image(systemName: "plus.square.fill")) \(Image(systemName: "minus.square"))")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView()) {
                            Text(Image(systemName: "gear"))
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            //.hideScrollEdgeEffect()
            //.toolbarBackground(backgroundGradient)
            //.toolbarBackgroundVisibility(.visible, for: ToolbarPlacement)
        }.environment(settings)
    }
}

#Preview {
    ContentView()
}
