import SwiftUI

// Detects what web Gerrit links in plain text: URLs (except email
// addresses) and Gerrit change-ids. Change-ids link into the app via the
// gerritview: URL scheme.
func linkifiedCommitMessage(_ message: String) -> AttributedString {
    let attributed = NSMutableAttributedString(string: message)
    let full = NSRange(location: 0, length: (message as NSString).length)
    var links: [(range: NSRange, url: URL)] = []
    let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    for match in detector?.matches(in: message, options: [], range: full) ?? [] {
        if let url = match.url, url.scheme != "mailto" {
            links.append((match.range, url))
        }
    }
    let changeIds = try? NSRegularExpression(pattern: "\\bI[0-9a-f]{40}\\b")
    for match in changeIds?.matches(in: message, options: [], range: full) ?? [] {
        // URLs win over change-ids on overlap.
        if links.contains(where: { $0.range.intersection(match.range) != nil }) {
            continue
        }
        let id = (message as NSString).substring(with: match.range)
        if let url = URL(string: "gerritview://change/" + id) {
            links.append((match.range, url))
        }
    }
    for (range, url) in links {
        attributed.addAttribute(.link, value: url, range: range)
    }
    return AttributedString(attributed)
}

struct CommitMessageView: View {
    var commit: CommitInfo?

    var body: some View {
        if let message = commit?.message {
            Text(linkifiedCommitMessage(message))
                .fontDesign(.monospaced)
                .font(.footnote)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

struct CommitFilesListView: View {
    let change: GerritChange
    let revision: String
    let files: [String: FileInfo]?
    let commentsByFile: [String: [CommentInfo]]?
    var olderCommentsByFile: [String: [CommentInfo]] = [:]

    private var paths: [String] {
        var all = Set<String>()
        if let files {
            all.formUnion(files.keys)
        }
        if let commentsByFile {
            // Skip pseudo-paths like "/PATCHSET_LEVEL" that hold comments
            // not attached to a file.
            all.formUnion(commentsByFile.keys.filter { !$0.hasPrefix("/") })
        }
        return all.sorted()
    }

    private func threadCount(for path: String) -> Int {
        return groupCommentThreads(commentsByFile?[path] ?? []).count
    }

    var body: some View {
        if files != nil || commentsByFile != nil {
            let sortedPaths: [String] = paths

            VStack(alignment: .leading) {
                    ForEach (sortedPaths, id: \.self) { key in
                        NavigationLink(
                            destination: ChangeDiffView(
                                changeId: change.tripletId,
                                revisionId: revision,
                                fileId: key,
                                commentsByFile: commentsByFile ?? [:],
                                olderCommentsByFile: olderCommentsByFile,
                                paths: sortedPaths
                            )
                        ) {
                            CommitFileRowView(
                                path: key,
                                file: files?[key],
                                commentThreadCount: threadCount(for: key)
                            )
                            if key != sortedPaths.last {
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

extension FileInfo {
    var sizeDeltaText: String {
        let value = abs(sizeDelta)
        let sign = sizeDelta < 0 ? "-" : "+"
        let units: [(Int64, String)] = [(1_000_000_000, "GB"), (1_000_000, "MB"), (1_000, "kB")]
        for (factor, unit) in units {
            if value >= factor {
                let size = Double(value) / Double(factor)
                return sign + String(format: "%.1f", size) + " " + unit
            }
        }
        return sign + String(value) + " bytes"
    }
}

struct CommitFileRowView: View {
    let path: String
    let file: FileInfo?
    let commentThreadCount: Int

    var body: some View {
        VStack(alignment: .leading) {
            Text(path).font(.subheadline)
            HStack {
                Text(file?.status ?? "")
                Spacer()

                if commentThreadCount > 0 {
                    Image(systemName: "text.bubble").font(.footnote)
                    Text(String(commentThreadCount)).font(.footnote)
                }

                if let file {
                    if file.binary != nil {
                        Text("binary \(file.sizeDeltaText)")
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .font(.footnote)
                    } else {
                        Text("+\(String(file.linesInserted ?? 0))")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                        Text("-\(String(file.linesDeleted ?? 0))")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                } else {
                    Text("no diff")
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .font(.footnote)
                }
            }
        }
    }
}

struct RequirementBadgeView: View {
    let name: String
    let status: SubmitRequirementResultStatus

    private var initials: String {
        return name.split(whereSeparator: { $0 == " " || $0 == "-" })
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0).uppercased() }
            .joined()
    }

    private var color: Color {
        switch status {
        case .satisfied, .overridden, .forced:
            return .green
        case .unsatisfied, .error:
            return .red
        case .notApplicable:
            return .gray
        }
    }

    var body: some View {
        Text(initials)
            .font(.caption).fontWeight(.bold)
            .minimumScaleFactor(0.5)
            .foregroundColor(.white)
            .frame(width: 26, height: 26)
            .background(color, in: Circle())
    }
}

struct VotePillInfo: Hashable, Identifiable {
    let id = UUID()
    let label: String
    let value: Int
}

struct VotePillView: View {
    let labelName: String
    let value: Int

    var color: Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .gray
    }

    var symbol: String {
        if value > 0 { return "+" }
        return ""
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(labelName)
                .font(.caption)
                .fontWeight(.medium)
            Text(symbol + String(value))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }
}



extension String {
    var firstLine: String {
        return self.components(separatedBy: .newlines).first ?? self
    }

    func extractGerritVotePrefix() -> (String, [VotePillInfo]) {
        var cleaned = self
        var pills: [VotePillInfo] = []

        let prefixRegex = try? NSRegularExpression(pattern: #"^Patch Set \d+:.*"#, options: [])
        guard (prefixRegex?.firstMatch(in: self.firstLine,
                                       options: [],
                                       range: NSRange(0..<self.firstLine.utf16.count))) != nil else {
            return (self, [])
        }

        if self.firstLine.localizedCaseInsensitiveContains("Cherry Picked from") {
            return (self, [])
        }

        let voteRegex = try? NSRegularExpression(
            pattern: #"\s*([A-Za-z][A-Za-z0-9\-_]*)\s*([+-]\d+)\s*"#,
            options: []
        )

        if let matches = voteRegex?.matches(in: self.firstLine,
                                            options: [],
                                            range: NSRange(0..<self.firstLine.utf16.count)),
           !matches.isEmpty {
            for match in matches {
                let labelRange = Range(match.range(at: 1), in: firstLine)
                let valueRange = Range(match.range(at: 2), in: firstLine)

                guard let labelRange, let valueRange else {
                    break
                }

                let label = String(firstLine[labelRange])
                let valueString = String(firstLine[valueRange])
                guard let value = Int(valueString) else {
                    break
                }

                pills.append(VotePillInfo(label: label, value: value))
            }

            cleaned = self
                .components(separatedBy: .newlines)
                .dropFirst().joined(separator: "\n")
        }

        return (cleaned, pills)
    }
}


struct CommentText: View {
    private var message: ChangeMessageInfo
    @State private var dynamicHeight: CGFloat = 100
    @State private var votePills: [VotePillInfo] = []

    init(message: ChangeMessageInfo) {
        self.message = message
    }

    var body: some View {
        CommentTextViewRepresentable(message: self.message, calculatedHeight: $dynamicHeight)
            .frame(
                minHeight: dynamicHeight,
                maxHeight: dynamicHeight
            )
            .overlay(alignment: .topTrailing) {
                // Vote badge pinned to the comment, like on Gerrit web
                if !votePills.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(votePills) { pill in
                            VotePillView(labelName: pill.label, value: pill.value)
                        }
                    }
                    .padding(2)
                }
            }
            .onAppear {
                let (_, pills) = message.message.extractGerritVotePrefix()
                votePills = pills
            }
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

    // Message body links are routed to the root URL handler through this
    // notification.
    static let linkTappedNotification = Notification.Name("GerritViewLinkTapped")

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

        // Link clicks are handled explicitly; the default UITextView link
        // interaction is unreliable here.
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        textField.addGestureRecognizer(tap)

        //textField.textLayoutManager!.delegate = commentLayoutDelegate
        return textField
    }

    private func processString(str: String) -> NSAttributedString {
        let (voteString, _) = str.extractGerritVotePrefix()
        let cleanedString = voteString.trimmingCharacters(in: .whitespacesAndNewlines)

        let attributedString = NSMutableAttributedString(string: cleanedString)

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
        for match in acct_matches.reversed() {
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

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        // Only claim the click when it lands on a link, so plain text keeps
        // its default selection behavior.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let textView = gestureRecognizer.view as? UITextView else {
                return false
            }
            return linkURL(at: gestureRecognizer.location(in: textView), in: textView) != nil
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView,
                  let url = linkURL(at: gesture.location(in: textView), in: textView) else {
                return
            }
            if url.scheme == "gerritview" {
                NotificationCenter.default.post(name: CommentTextViewRepresentable.linkTappedNotification, object: url)
            } else {
                // External URLs go to the system browser.
                UIApplication.shared.open(url)
            }
        }

        private func linkURL(at point: CGPoint, in textView: UITextView) -> URL? {
            guard let position = textView.closestPosition(to: point) else {
                return nil
            }
            let index = textView.offset(from: textView.beginningOfDocument, to: position)
            guard index >= 0, index < textView.attributedText.length else {
                return nil
            }
            switch textView.attributedText.attribute(.link, at: index, effectiveRange: nil) {
            case let url as URL:
                return url
            case let string as String:
                return URL(string: string)
            default:
                return nil
            }
        }
    }
}

struct CommitCommentsListView: View {
    let comments: [ChangeMessageInfo]?
    let threadsByMessage: [String: [CommentThread]]
    var nav: CommentThreadNavContext? = nil
    @Environment(Settings.self) var settings: Settings

    var body: some View {
        if let comments {
            let newestFirst = settings.reverseComments
            let items = comments.sorted { newestFirst ? $0.date > $1.date : $0.date < $1.date }
            VStack(alignment: .leading) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, message in
                    if index != 0 {
                        Divider()
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            let author: String = message.author?.Name() ?? "Gerrit" + (
                                (
                                    message.realAuthor != nil
                                ) ? " on behalf of " + message.realAuthor!.Name() : ""
                            )

                            UserpicView(account: message.author ?? message.realAuthor, size: 16)
                            Text(message.date.formatted()).font(.footnote)
                            if (message.revisionNumber != nil) {
                                Text("PS\(message.revisionNumber!)")
                                    .font(.footnote)
                            }
                            Text(author)
                                .font(.footnote)
                        }
                        VStack(alignment: .leading) {
                            CommentText(message: message)
                            ForEach(threadsByMessage[message.id] ?? [], id: \.comments.first?.id) { thread in
                                CommentThreadRow(thread: thread, nav: nav)
                            }
                        }
                    }
                }
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ChangePageLoadedView: View {
    let change: GerritChange
    let commentsByFile: [String: [CommentInfo]]
    @State private var showOlderPatchsets = false
    @Environment(Settings.self) var settings: Settings

    private var currentPatchSet: Int? {
        return change.currentRevisionNumber
    }

    private var visibleComments: [String: [CommentInfo]] {
        return commentsForPatchSet(
            commentsByFile,
            current: currentPatchSet,
            showOlder: showOlderPatchsets
        )
    }

    private var threadsByMessage: [String: [CommentThread]] {
        return threadsForChangeMessages(commentsByFile)
    }

    // Messages from older patch sets are hidden behind the toggle, except the
    // ones that published inline comments; their comments stay visible.
    private func messagesVisible(showOlder: Bool) -> [ChangeMessageInfo] {
        let messages = change.messages ?? []
        let current = messagesForPatchSet(messages, current: currentPatchSet, showOlder: showOlder)
        let publishers = Set(threadsByMessage.keys)
        return messages.filter { message in
            return current.contains { $0.id == message.id } || publishers.contains(message.id)
        }
    }

    private var hasHiddenMessages: Bool {
        let messages = change.messages ?? []
        return messages.count > messagesVisible(showOlder: false).count
    }

    // Navigating from a comment row to the file the comment is anchored to.
    private var commentNavContext: CommentThreadNavContext? {
        guard let revisions = change.revisions,
              let currentRevision = change.currentRevision,
              let currentRevisionContent = revisions[currentRevision]
        else {
            return nil
        }
        var paths = Set<String>()
        if let files = currentRevisionContent.files {
            paths.formUnion(files.keys)
        }
        paths.formUnion(commentsByFile.keys.filter { !$0.hasPrefix("/") })
        return CommentThreadNavContext(
            changeId: change.tripletId,
            revisionId: currentRevision,
            paths: paths.sorted(),
            commentsByFile: visibleComments,
            olderCommentsByFile: olderComments
        )
    }

    // Comments from patch sets older than the current one. Shown even when
    // older patch sets are not listed; empty while they are, to avoid
    // showing them twice.
    private var olderComments: [String: [CommentInfo]] {
        guard !showOlderPatchsets, let current = currentPatchSet else {
            return [:]
        }
        var result: [String: [CommentInfo]] = [:]
        for (path, comments) in commentsByFile {
            let older = comments.filter { comment in
                guard let patchSet = comment.patchSet else {
                    return false
                }
                return patchSet != current
            }
            if !older.isEmpty {
                result[path] = older
            }
        }
        return result
    }

    private var changeUrl: String {
        return "\(settings.gerritUrl)/c/\(change.project)/+/\(change.number)"
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.subject).font(.headline)
                    changeStatusIcon(status: change.status)
                    if let unresolved = change.unresolvedCommentCount, unresolved > 0 {
                        Text("\(Image(systemName: "exclamationmark.bubble")) \(unresolved) unresolved")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Text("#" + String(change.number))
                    HStack(spacing: 4) {
                        UserpicView(account: change.owner, size: 16)
                        Text(change.owner.Name())
                    }
                    .font(.subheadline)
                    Text("\(Image(systemName: "folder"))\(change.project)")
                    Text("\(Image(systemName: "arrow.trianglehead.branch"))\(change.branch)")
                    if (change.submitRequirements != nil) {
                        ForEach(change.submitRequirements!) { requirement in
                            if (
                                requirement.status != .notApplicable
                            ) {
                                HStack {
                                    RequirementBadgeView(name: requirement.name, status: requirement.status)
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
                    if hasHiddenMessages {
                        Toggle(
                            "Messages from older patchsets",
                            isOn: $showOlderPatchsets
                        )
                            .font(.subheadline)
                    }
                    CommitFilesListView(
                        change: change,
                        revision: currentRevision,
                        files: currentRevisionContent.files,
                        commentsByFile: visibleComments,
                        olderCommentsByFile: olderComments
                    )
                }

                CommitCommentsListView(
                    comments: messagesVisible(showOlder: showOlderPatchsets),
                    threadsByMessage: threadsByMessage,
                    nav: commentNavContext
                )
            }.padding(4)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: changeUrl)
            }
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
        case .loaded(let change, let commentsByFile):
            ChangePageLoadedView(change: change, commentsByFile: commentsByFile)
                .refreshable {
                    await self.gerritChangeModel
                        .fetchChange(settings: settings, changeId: changeId)
                }
        }
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
        Text("Active")
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
