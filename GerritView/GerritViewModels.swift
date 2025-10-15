import SwiftUI

func composeCommonPartOfGerritUrl(settings: Settings) -> (URL, [URLQueryItem]) {
    let endpoint = URL(string: settings.gerritUrl)!

    if settings.gerritUsePasswordAuth {
        let host = endpoint.host()
        let credential = URLCredential(user: settings.gerritUsername, password: settings.gerritPassword, persistence: URLCredential.Persistence.forSession)
        let protectionSpace = URLProtectionSpace(
            host: host!,
            port: 443,
            protocol: "https",
            realm: "Gerrit Code Review",  // Big TODO
            authenticationMethod: NSURLAuthenticationMethodHTTPBasic
        )
        URLCredentialStorage.shared.setDefaultCredential(credential, for: protectionSpace)
    }
    
    var queryItems = [
        URLQueryItem(name: "pp", value: "0")
    ]
    if settings.gerritUseCookieAuth {
        queryItems
            .append(
                URLQueryItem(name: "access_token", value: settings.gerritCookie)
            )
    }
    return (endpoint, queryItems)
}

func composeChangesListGerritUrl(settings: Settings, query: String?, skip: Int, loadCount: Int) -> URL {
    var (url, queryItems) = composeCommonPartOfGerritUrl(settings: settings)
    
    url = url.appendingPathComponent("changes")
    queryItems.append(contentsOf: [
        URLQueryItem(name: "o", value: "DETAILED_ACCOUNTS"),
        URLQueryItem(name: "o", value: "SUBMIT_REQUIREMENTS"),
        URLQueryItem(name: "n", value: String(loadCount)),
        URLQueryItem(name: "S", value: String(skip)),
        URLQueryItem(name: "q", value: (query ?? "").isEmpty ? "is:open" : query!)
    ])

    url.append(queryItems: queryItems)
    //print(url)
    return url
}

func composeSingleChangeGerritUrl(settings: Settings, change: String) -> URL {
    var (url, queryItems) = composeCommonPartOfGerritUrl(settings: settings)
    
    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    urlComponents.percentEncodedPath = url.path() + "/changes/" + change
    url = urlComponents.url!
    queryItems.append(contentsOf: [
        URLQueryItem(name: "o", value: "DETAILED_ACCOUNTS"),
        URLQueryItem(name: "o", value: "SUBMIT_REQUIREMENTS"),
        URLQueryItem(name: "o", value: "CURRENT_REVISION"),
        URLQueryItem(name: "o", value: "CURRENT_COMMIT"),
        URLQueryItem(name: "o", value: "CURRENT_FILES"),
        URLQueryItem(name: "o", value: "DETAILED_LABELS"),
        URLQueryItem(name: "o", value: "MESSAGES"),
        URLQueryItem(name: "o", value: "CURRENT_ACTIONS"),
        URLQueryItem(name: "o", value: "CHANGE_ACTIONS"),
        URLQueryItem(name: "o", value: "WEB_LINKS"),
        URLQueryItem(name: "o", value: "CHECK"),
        URLQueryItem(name: "o", value: "COMMIT_FOOTERS"),
        URLQueryItem(name: "o", value: "CUSTOM_KEYED_VALUES")
    ])

    url.append(queryItems: queryItems)
    //print(url)
    return url
}

@Observable class GerritChangePageViewModel {
    enum State {
        case empty
        case failed(Error)
        case loaded(GerritChange)
    }
    var state: State = State.empty

    func fetchChange(changeId: String, settings: Settings) async {
        let queryUrl = composeSingleChangeGerritUrl(
            settings: settings,
            change: changeId
        )

        do {
            let (json, _) = try await URLSession.shared.data(from: queryUrl)
            //print(String(data: json, encoding: .utf8)!)
            let change = try decodeGerritSingleChangeResponse(
                from: String(data: json, encoding: .utf8)!
            )
            self.state = State.loaded(change!)
        } catch {
            let nsError = error as NSError

            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorCancelled {
                // print("cancelled")
            } else {
                self.state = State.failed(error)
                print(error)
            }
        }
    }
}

@Observable class GerritChangesListViewModel {
    var changes: [GerritChange] = []
    var showAlert = false
    var errorMessage = ""
    var fetched = 0
    let loadCount = 10
    
    func clearChanges() {
        self.fetched = 0
        self.changes = []
    }

    func fetchChanges(settings: Settings, query: String?, more: Bool) async {
        let queryUrl = composeChangesListGerritUrl(
            settings: settings,
            query: query,
            skip: more ? fetched : 0,
            loadCount: loadCount
        )
        // TODO: "if you’re doing anything with caches, cookies, authentication,
        // or custom networking protocols, you should probably be using a default
        // session instead of the shared session"
        // -- https://developer.apple.com/documentation/foundation/urlsession/shared
        do {
            let (json, _) = try await URLSession.shared.data(from: queryUrl)
            //print(String(data: json, encoding: .utf8)!)
            let newChanges = try decodeGerritChangeListResponse(
                from: String(data: json, encoding: .utf8)!
            )
            if (!more) {
                self.clearChanges()
            }
            let allChanges = self.changes + newChanges
            var alreadyThere = Set<String>()
            self.changes = allChanges.compactMap { (
                change
            ) -> GerritChange? in
                guard !alreadyThere.contains(change.id) else { return nil }
                alreadyThere.insert(change.id)
                return change
            }
            self.showAlert = false
        } catch {
            let nsError = error as NSError

            if nsError.domain == NSURLErrorDomain,
               nsError.code == NSURLErrorCancelled {
                // print("cancelled")
            } else {
                self.errorMessage = error.localizedDescription
                self.showAlert = true
                print(error)
            }
        }
        fetched += loadCount
    }
}
