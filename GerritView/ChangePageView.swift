import SwiftUI

struct CommitMessageView: View {
    var commit: CommitInfo?
    
    var body: some View {
        if commit?.message != nil {
            Text(
                verbatim: commit!.message!
            ).fontDesign(.monospaced).font(.footnote).fontWeight(.semibold).frame(
                maxWidth: .infinity,
                alignment: .leading
            )
                .padding(4)
                .background(
                    Color(UIColor.systemGroupedBackground)
                )
        }
    }
}

struct CommitFilesListView: View {
    let files: [String: FileInfo]?
    
    var body: some View {
        if files != nil {
            let sortedKeys: [String] = files!.keys.sorted()

            VStack(alignment: .leading) {
                ForEach (sortedKeys, id: \.self) { key in
                    VStack(alignment: .leading) {
                        Text(key).font(.subheadline)
                        HStack {
                            Text(files![key]?.status ?? "")
                            Spacer()
                            
                            if files![key]?.binary != nil {
                                Text("binary \(String((files![key]?.sizeDelta)!))")
                                    .foregroundStyle(
                                        Color(uiColor: .secondaryLabel)
                                    )
                                    .font(.footnote)
                            } else {
                                Text(
                                    "+\(String(files![key]?.linesInserted ?? 0))"
                                )
                                .foregroundStyle(.green)
                                .font(.subheadline)
                                Text(
                                    "-\(String(files![key]?.linesDeleted ?? 0))"
                                )
                                .foregroundStyle(.red)
                                .font(.subheadline)
                            }
                        }
                    }
                    if key != sortedKeys.last {
                        Divider()
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}


struct CommitCommentsListView: View {
    let comments: [ChangeMessageInfo]?

    var body: some View {
        if comments != nil {
            VStack(alignment: .leading) {
                ForEach (comments!) { message in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(message.date.formatted()).font(.footnote)
                            Text(message.author!.Name()).font(.footnote)
                        }.padding(.bottom)
                        Text(message.attributedMessage!).font(.subheadline)
                    }
                    if message.id != comments?.last?.id {
                        Divider()
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ChangePageView: View {
    var changeId: String
    @State private var gerritChangeModel = GerritChangePageViewModel()
    @Environment(Settings.self) var settings: Settings
    
    var body: some View {
        @Bindable var settings = settings
        
        switch gerritChangeModel.state {
        case .empty:
            ProgressView()
            .task {
                await self.gerritChangeModel
                    .fetchChange(changeId: changeId, settings: settings)
            }
        case .failed(let error):
            Text(error.localizedDescription)
        case .loaded(let change):
            ScrollView(.vertical) {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.subject).font(.headline)
                        changeStatusIcon(status: change.status)
                        Text("\(Image(systemName: "folder"))\(change.project)")
                        Text("\(Image(systemName: "arrow.trianglehead.branch"))\(change.branch)")
                        if (change.submitRequirements != nil) {
                            ForEach(change.submitRequirements!) { requirement in
                                if (
                                    requirement.status != .notApplicable
                                ) {
                                    HStack {
                                        requirementIcon(status: requirement.status)
                                            .font(.subheadline)
                                        Text(requirement.name)
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    if let revisions = change.revisions,
                       let currentRevision = change.currentRevision,
                       let currentRevisionContent = revisions[currentRevision]
                    {
                        CommitMessageView(commit: currentRevisionContent.commit)
                        CommitFilesListView(files: currentRevisionContent.files)
                    }
                    
                    CommitCommentsListView(comments: change.messages)
                }.padding(4)
            }
            .refreshable {
                await self.gerritChangeModel
                    .fetchChange(changeId: changeId, settings: settings)
            }
        }
    }
}
