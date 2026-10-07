import SwiftUI

struct ChangeRowView: View {
    var change: GerritChange
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
                UserpicView(account: change.owner, size: 18)
                Text(change.owner.Name())
                    .font(.subheadline)
            }
            switch change.status {
            case .abandoned:
                Text(change.subject)
                    .font(.headline)
                    .foregroundStyle(.gray)
            case .new:
                Text(change.subject).font(.headline)
            case .merged:
                Text(change.subject).font(.headline).foregroundStyle(Color(hue: 0.38, saturation: 0.68, brightness: 0.53))
            }
            Text(change.project).font(.subheadline)
            if let unresolved = change.unresolvedCommentCount, unresolved > 0 {
                Text("\(Image(systemName: "exclamationmark.bubble")) \(unresolved) unresolved")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            VStack(alignment: .trailing) {
                if (change.submitRequirements != nil) {
                    ForEach(change.submitRequirements!) { requirement in
                        if (
                            requirement.status != .notApplicable
                        ) {
                            HStack {
                                Spacer()
                                RequirementBadgeView(name: requirement.name, status: requirement.status)
                            }
                        }
                    }
                }
            }/*.rotation3DEffect(
                .degrees(-20),
                axis: (x: 0, y: 1, z: 0),
                anchor: .trailing, perspective: 1.0
            )*/
        }
    }
}

struct ChangeListView: View {
    @State private var gerritChangesModel = GerritChangesListViewModel()
    @Environment(Settings.self) var settings: Settings
    @State private var searchText = ""
    @State private var queryText = ""
    @State private var savedFilters: [String] = UserDefaults.standard.stringArray(forKey: "settingsSavedFilters") ?? []
    @State private var showingQueryDeletion = false

    private func applySavedFilter(_ filter: String) {
        searchText = filter
        queryText = filter
        gerritChangesModel.clearChanges()
        Task {
            await self.gerritChangesModel.fetchChanges(settings: settings, query: filter, more: false)
        }
    }

    private func saveCurrentQuery() {
        guard !queryText.isEmpty, !savedFilters.contains(queryText) else { return }
        savedFilters.append(queryText)
        settings.savedFilters = savedFilters
    }

    var body: some View {
        @Bindable var settings = settings
        ScrollViewReader { proxy in
            List {
                ForEach($gerritChangesModel.changes) { $change in
                    NavigationLink(
                        destination: ChangePageView(
                            changeId: change.tripletId
                        )
                    ) {
                        ChangeRowView(change: change)
                    }
                }
                if gerritChangesModel.hasMore {
                    ProgressView()
                        .task { await self.gerritChangesModel.fetchChanges(settings: settings, query: queryText, more: true) }
                }
            }
            .listStyle(.plain)
            .navigationDestination(isPresented: $showingQueryDeletion) {
                SavedQueriesView(savedFilters: $savedFilters)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if let first = gerritChangesModel.changes.first {
                            proxy.scrollTo(first.id, anchor: .top)
                        }
                        Task {
                            await self.gerritChangesModel.fetchChanges(settings: settings, query: queryText, more: false)
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Save current query", systemImage: "bookmark.plus") {
                            saveCurrentQuery()
                        }
                        .disabled(queryText.isEmpty)
                        Section("Saved queries") {
                            ForEach(savedFilters, id: \.self) { filter in
                                Button(filter) {
                                    applySavedFilter(filter)
                                }
                            }
                        }
                        if !savedFilters.isEmpty {
                            Button("Delete saved queries...", systemImage: "trash") {
                                showingQueryDeletion = true
                            }
                        }
                    } label: {
                        Image(systemName: "bookmark")
                    }
                }
            }
            .refreshable {
                await self.gerritChangesModel.fetchChanges(settings: settings, query: queryText, more: false)
            }
            .searchable(text: $searchText)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) {
                queryText = searchText
                gerritChangesModel.clearChanges()
            }
            .onChange(of: searchText) { _, newValue in
                // Clearing the field with X does not trigger onSubmit.
                if newValue.isEmpty && !queryText.isEmpty {
                    queryText = newValue
                    Task {
                        await self.gerritChangesModel.fetchChanges(settings: settings, query: nil, more: false)
                    }
                }
            }
            .alert("Communication failure", isPresented: $gerritChangesModel.showAlert, presenting: gerritChangesModel.errorMessage) { _ in
                Button("Dismiss") {  }
            } message: { details in
                Text(details)
            }
        }
    }
}

struct SavedQueriesView: View {
    @Binding var savedFilters: [String]
    @Environment(Settings.self) var settings: Settings

    var body: some View {
        List {
            ForEach(savedFilters, id: \.self) { filter in
                HStack {
                    Text(filter)
                    Spacer()
                    Button {
                        savedFilters.removeAll { $0 == filter }
                        settings.savedFilters = savedFilters
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .navigationTitle("Delete saved queries")
    }
}
