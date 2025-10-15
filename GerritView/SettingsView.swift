import SwiftUI
internal import Combine

@Observable class Settings {
    class Storage {
        @AppStorage("settingsGerritUrlKey") var gerritUrl: String = "https://android-review.googlesource.com"
        @AppStorage("settingsGerritUseCookieAuth") var gerritUseCookieAuth: Bool = false
        @AppStorage("settingsGerritUsePasswordAuth") var gerritUsePasswordAuth: Bool = false
        @AppStorage("settingsGerritCookie") var gerritCookie: String = ""
        @AppStorage("settingsGerritUsername") var gerritUsername: String = ""
        @AppStorage("settingsGerritPassword") var gerritPassword: String = ""

    }
    
    private let storage = Storage()
    
    var gerritUrl: String {
        didSet { storage.gerritUrl = gerritUrl }
    }
    var gerritUsePasswordAuth: Bool {
        didSet { storage.gerritUsePasswordAuth = gerritUsePasswordAuth }
    }
    var gerritUseCookieAuth: Bool {
        didSet { storage.gerritUseCookieAuth = gerritUseCookieAuth }
    }
    var gerritCookie: String {
        didSet { storage.gerritCookie = gerritCookie }
    }
    var gerritUsername: String {
        didSet { storage.gerritUsername = gerritUsername }
    }
    var gerritPassword: String {
        didSet { storage.gerritPassword = gerritPassword }
    }
    
    init() {
        gerritUrl = storage.gerritUrl
        gerritUsePasswordAuth = storage.gerritUsePasswordAuth
        gerritUseCookieAuth = storage.gerritUseCookieAuth
        gerritCookie = storage.gerritCookie
        gerritUsername = storage.gerritUsername
        gerritPassword = storage.gerritPassword
    }
}

struct SettingsView: View {
    @Environment(Settings.self) var settings
    
    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                TextField(text: $settings.gerritUrl, prompt: Text("Required"))
                {
                    Text("Gerrit instance URL")
                }
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                Toggle("Use password authentication", systemImage: "lock.fill", isOn: $settings.gerritUsePasswordAuth)
                if settings.gerritUsePasswordAuth {
                    TextField(text: $settings.gerritUsername, prompt: Text("Username"))
                    {
                        Text("Username")
                    }
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    SecureField(text: $settings.gerritPassword, prompt: Text("Password"))
                    {
                        Text("Password")
                    }
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                }
                Toggle("Use cookie authentication", systemImage: "lock.fill", isOn: $settings.gerritUseCookieAuth)
                    .disabled(true)
                if settings.gerritUseCookieAuth {
                    SecureField(text: $settings.gerritCookie, prompt: Text("Cookie"))
                    {
                        Text("Cookie")
                    }
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Gerrit instance configuration")
            } footer: {
                if settings.gerritUsePasswordAuth {
                    Text(
                        "To obtain the username and password, navigate to \"HTTP Credentials\" in your Gerrit profile settings."
                    )
                }
                if settings.gerritUseCookieAuth {
                    Text(
                        "To obtain the cookie, navigate to \"HTTP Credentials\" in your Gerrit profile settings. Click \"Obtain password\". Paste only the field after \",o,\".\nFor example, android.googlesource.com,FALSE,/,TRUE,2147483647,o,**git-example.example.com=1//0321FooBaarBaaazz**..."
                    )
                }
            }
        }
    }
}
