import SwiftUI

struct ChangeDiffView: View {
    let changeId: String
    let revisionId: String
    let file: FileInfo
    let fileId: String

    @State private var gerritDiffModel = GerritFileDiffViewModel()
    @Environment(Settings.self) var settings: Settings

    var body: some View {
        @Bindable var settings = settings

        switch gerritDiffModel.state {
        case .empty:
            ProgressView()
                .task {
                    await self.gerritDiffModel
                        .fetchDiff(
                            settings: settings,
                            changeId: changeId,
                            revisionId: String(revisionId),
                            fileId: fileId
                        )
                }
        case .failed(let error):
            Text(error.localizedDescription)
        case .loaded(let diff):
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(diff.changeType.rawValue).font(.headline)
                    Text(
                        verbatim: diff.diffHeader.joined(separator: " ")
                    ).fontDesign(.monospaced).font(.footnote).fontWeight(.semibold).frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .padding(4)
                    .background(
                        Color(UIColor.systemGroupedBackground)
                    )
                    ForEach(diff.content) { content in
                        if content.a != nil {
                            Text(
                                verbatim: content.a!.joined(separator: "\n")
                            ).fontDesign(.monospaced).font(.footnote).fontWeight(.semibold).frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(4)
                            .background(
                                Color(UIColor.init(
                                    red: CGFloat(0xE8) / 255.0,
                                    green: CGFloat(0xDC) / 255.0,
                                    blue: CGFloat(0xDA) / 255.0,
                                    alpha: 1.0
                                )
                                ))
                        }
                        if content.b != nil {
                            Text(
                                verbatim: content.b!.joined(separator: "\n")
                            ).fontDesign(.monospaced).font(.footnote).fontWeight(.semibold).frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(4)
                            .background(
                                Color(UIColor.init(
                                    red: CGFloat(0xDC) / 255.0,
                                    green: CGFloat(0xE8) / 255.0,
                                    blue: CGFloat(0xDA) / 255.0,
                                    alpha: 1.0
                                )
                                ))
                        }
                        if content.ab != nil {
                            Text(
                                verbatim: content.ab!.joined(separator: "\n")
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
            }
        }
    }
}
