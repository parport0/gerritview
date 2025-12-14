import SwiftUI

struct ChangeRowView: View {
    var change: GerritChange
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(change.owner.Name())
                .font(.subheadline)
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
            VStack(alignment: .trailing) {
                if (change.submitRequirements != nil) {
                    ForEach(change.submitRequirements!) { requirement in
                        if (
                            requirement.status != .notApplicable
                        ) {
                            HStack {
                                Spacer()
                                Text(requirement.name)
                                    .font(.subheadline)
                                requirementIcon(status: requirement.status)
                                    .font(.subheadline)
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
    
    var body: some View {
        @Bindable var settings = settings
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
                ProgressView()
                    .task { await self.gerritChangesModel.fetchChanges(settings: settings, query: searchText, more: true) }
            }
            .listStyle(.plain)
            .refreshable {
                await self.gerritChangesModel.fetchChanges(settings: settings, query: searchText, more: false)
            }
            .searchable(text: $searchText)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .onSubmit(of: .search) {
                queryText = searchText
                gerritChangesModel.clearChanges()
            }
        .alert("Communication failure", isPresented: $gerritChangesModel.showAlert, presenting: gerritChangesModel.errorMessage) { _ in
            Button("Dismiss") {  }
        } message: { details in
            Text(details)
        }
    }
}
