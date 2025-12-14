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
    let change: GerritChange
    let revision: String
    let files: [String: FileInfo]?
    
    var body: some View {
        if files != nil {
            let sortedKeys: [String] = files!.keys.sorted()

            VStack(alignment: .leading) {
                    ForEach (sortedKeys, id: \.self) { key in
                        NavigationLink(
                            destination: ChangeDiffView(
                                changeId: change.tripletId,
                                revisionId: revision,
                                file: files![key]!,
                                fileId: key
                            )
                        ) {
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
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
}


struct CommentText: View {
    private var message: ChangeMessageInfo
    @State private var dynamicHeight: CGFloat = 100

    init (message: ChangeMessageInfo) {
        self.message = message
    }

    var body: some View {
        CommentTextViewRepresentable(message: self.message, calculatedHeight: $dynamicHeight)
            .frame(
                minHeight: dynamicHeight,
                maxHeight: dynamicHeight
            )
    }
}

/*class CommentTextLayoutManagerDelegate: NSObject, NSTextLayoutManagerDelegate {
    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: any NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {

        return NSTextLayoutFragment(textElement: textElement, range: textElement.elementRange)
    }
}*/

/*extension NSAttributedString.Key {
    static let isGerritAccount = NSAttributedString.Key("IsGerritAccount")
}*/

struct CommentTextViewRepresentable: UIViewRepresentable {
    typealias UIViewType = UITextView

    var message: ChangeMessageInfo
    @Binding var calculatedHeight: CGFloat

    //let commentLayoutDelegate = CommentTextLayoutManagerDelegate()

    func makeUIView(context: UIViewRepresentableContext<CommentTextViewRepresentable>) -> UITextView {

        let textField = UITextView(usingTextLayoutManager: true)

        textField.isEditable = false
        textField.isSelectable = true
        textField.isUserInteractionEnabled = true
        textField.isScrollEnabled = false
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.textContainer.lineBreakMode = .byCharWrapping
        //textField.textLayoutManager!.delegate = commentLayoutDelegate
        return textField
    }

    private func processString(str: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: str)

        // Find links
        let types = NSTextCheckingResult.CheckingType.link.rawValue
        guard let detector = try? NSDataDetector(types: types) else {
            return attributedString
        }
        let url_matches = detector.matches(in: attributedString.string, options: [], range: NSRange(location: 0, length: attributedString.string.utf16.count))
        for match in url_matches {
            let range = match.range
            let link = (attributedString.string as NSString).substring(with: range)
            let replacement = NSAttributedString(string: link, attributes: [.link: link])
            attributedString.replaceCharacters(in: range, with: replacement)
        }

        // Find Gerrit account names
        // Regex from Gerrit's AccountTemplateUtil.java
        let regex = try? NSRegularExpression(pattern: "<GERRIT_ACCOUNT_([0-9]+)>")
        let acct_matches = (
            regex!
                .matches(
                    in: attributedString.string,
                    range: NSRange(
                        location: 0,
                        length: attributedString.string.utf16.count
                    )
                )
        )
        for match in acct_matches {
            let acct_id = (attributedString.string as NSString).substring(
                with: match.range(at: 1)
            )
            var acct_name = acct_id
            for account in message.accountsInMessage! {
                if account.accountId == Int(acct_id)! {
                    acct_name = account.Name()
                }
            }
            let replacement = NSAttributedString(
                string: acct_name,
                attributes: [
                    /*.isGerritAccount: true,*/
                    .foregroundColor: UIColor(.blue),
                    .backgroundColor: UIColor.secondarySystemBackground,
                    .link: "gerritview://" + acct_id
                ]
            )
            attributedString.replaceCharacters(in: match.range, with: replacement)

        }

        return attributedString
    }

    func updateUIView(_ uiView: UITextView, context: UIViewRepresentableContext<CommentTextViewRepresentable>) {
        uiView.attributedText = processString(str: self.message.message)

        CommentTextViewRepresentable
            .recalculateHeight(view: uiView, result: $calculatedHeight)
    }

    private static func recalculateHeight(view: UIView, result: Binding<CGFloat>) {
        let newSize = view.sizeThatFits(CGSize(width: view.frame.size.width, height: CGFloat.greatestFiniteMagnitude))
        if result.wrappedValue != newSize.height {
            DispatchQueue.main.async {
                result.wrappedValue = newSize.height
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UITextViewDelegate {
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
                            let author: String = message.author?.Name() ?? "Gerrit" + (
                                (
                                    message.realAuthor != nil
                                ) ? " on behalf of " + message.realAuthor!.Name() : ""
                            )

                            Text(message.date.formatted()).font(.footnote)
                            Text(author)
                                .font(.footnote)
                        }
                        CommentText(message: message)
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
                    .fetchChange(settings: settings, changeId: changeId)
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
                        CommitFilesListView(
                            change: change,
                            revision: currentRevision,
                            files: currentRevisionContent.files
                        )
                    }

                    CommitCommentsListView(comments: change.messages)
                }.padding(4)
            }
            .refreshable {
                await self.gerritChangeModel
                    .fetchChange(settings: settings, changeId: changeId)
            }
        }
    }
}

@ViewBuilder func requirementIcon(status: SubmitRequirementResultStatus) -> some View {
    switch status {
    case .satisfied:
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
    case .unsatisfied:
        Image(systemName: "x.circle.fill").foregroundStyle(.red)
    case .forced:
        Image(systemName: "checkmark.circle.trianglebadge.exclamationmark.fill").foregroundStyle(.green)
    case .overridden:
        Image(systemName: "checkmark.shield.fill").foregroundStyle(.green)
    case .error:
        Image(systemName: "questionmark.circle.fill")
            .foregroundStyle(.red)
    case .notApplicable:
        Image(systemName: "circle.fill")
    }
}

@ViewBuilder func changeStatusIcon(status: ChangeStatus) -> some View {
    switch status {
    case .abandoned:
        Text("ABANDONED")
            .padding(4)
            .fontWeight(.bold)
            .font(.subheadline)
            .foregroundStyle(.white)
            .background(Color.gray, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    case .merged:
        Text("MERGED")
            .padding(4)
            .fontWeight(.bold)
            .font(.subheadline)
            .foregroundStyle(.white)
            .background(Color.green, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    case .new:
        Text("NEW")
            .padding(4)
            .fontWeight(.bold)
            .font(.subheadline)
            .foregroundStyle(.white)
            .background(Color.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    @Previewable @State var settings = Settings()
    NavigationStack {
        ChangePageView(
            changeId: "platform%2Fmanifest~master~I76ee129f19dbfbda4ea9abadcb2e280c107aefab"
        ).environment(settings)
    }
}
