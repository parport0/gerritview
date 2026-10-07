import SwiftUI

class DiffScrollViewController: UIViewController {
    let entries: [DiffEntry]

    private let lineFont = UIFont.monospacedSystemFont(
        ofSize: UIFont.smallSystemFontSize,
        weight: .medium
    )

    init(entries: [DiffEntry]) {
        self.entries = entries
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func lineColor(_ line: DiffLine) -> UIColor {
        switch (line.beforeNumber, line.afterNumber) {
        case (.some, .none):
            return UIColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1.0)
        case (.none, .some):
            return UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0)
        default:
            return .label
        }
    }

    private func commentAttributedText(
        _ thread: CommentThread,
        background: UIColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
        let headerFont = UIFont.boldSystemFont(ofSize: UIFont.smallSystemFontSize)

        for comment in thread.comments {
            let side = comment.effectiveSide == .parent
                ? (comment.parentNumber.map { "parent \($0)" } ?? "before")
                : "after"
            let place = comment.isFileComment ? "file" : "\(side) line \(comment.endLine!)"
            let unresolvedMark = (comment.unresolved ?? false) ? "● " : ""
            let header = "\(unresolvedMark)\(comment.author?.Name() ?? "Unknown") · \(place)\n"
            result.append(NSAttributedString(
                string: header,
                attributes: [
                    .font: headerFont,
                    .foregroundColor: UIColor.secondaryLabel,
                    .backgroundColor: background
                ]
            ))
            result.append(NSAttributedString(
                string: (comment.message ?? "") + "\n",
                attributes: [
                    .font: bodyFont,
                    .foregroundColor: UIColor.label,
                    .backgroundColor: background
                ]
            ))
        }
        return result
    }

    private func generateTextView() -> UITextView {
        let summedText: NSMutableAttributedString = NSMutableAttributedString()

        for entry in entries {
            switch entry {
            case .line(let line):
                summedText.append(NSAttributedString(
                    string: line.text + "\n",
                    attributes: [.font: lineFont, .foregroundColor: lineColor(line)]
                ))
            case .skippedLines(_, _, let count):
                summedText.append(NSAttributedString(
                    string: "· · · \(count) hidden lines · · ·\n",
                    attributes: [
                        .font: lineFont,
                        .foregroundColor: UIColor.tertiaryLabel,
                        .obliqueness: 0.3
                    ]
                ))
            case .comments(let thread):
                let unresolved = thread.comments.last?.unresolved ?? false
                let background = unresolved
                    ? UIColor.systemYellow.withAlphaComponent(0.25)
                    : UIColor.secondarySystemBackground

                let commentText = NSMutableAttributedString()
                commentText.append(NSAttributedString(string: "\n", attributes: [.font: lineFont]))
                commentText.append(commentAttributedText(thread, background: background))
                commentText.append(NSAttributedString(string: "\n", attributes: [.font: lineFont]))
                summedText.append(commentText)
                summedText.addAttributes(
                    [.backgroundColor: background],
                    range: NSRange(
                        location: summedText.length - commentText.length,
                        length: commentText.length
                    )
                )
            }
        }

        let textView = UITextView(usingTextLayoutManager: true)
        textView.attributedText = summedText
        textView.isEditable = false
        textView.isSelectable = true

        return textView
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.textView.frame = view.frame
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .secondarySystemGroupedBackground
        let textView = generateTextView()
        view.addSubview(textView)
        self.textView = textView
        self.textView.frame = view.frame
    }

    private var textView: UITextView = UITextView()
}

struct DiffScrollViewControllerRepresentable: UIViewControllerRepresentable {
    let entries: [DiffEntry]

    func makeUIViewController(context: Context) -> UIViewController {
        return DiffScrollViewController(entries: entries)
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}
}

struct ChangeDiffView: View {
    let changeId: String
    let revisionId: String
    let fileId: String
    let comments: [CommentInfo]

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
                            fileId: fileId,
                            parentNumber: diffParentNumber(for: comments)
                        )
                }
        case .failed(let error):
            Text(error.localizedDescription)
        case .loaded(let diff):
            VStack(alignment: .leading, spacing: 2) {
                Text(diff.changeType.rawValue).font(.headline)
                Text(
                    verbatim: diff.diffHeader[2...3].joined(separator: "\n")
                ).fontDesign(.monospaced).font(.footnote).fontWeight(.semibold).frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding(4)
                .background(
                    Color(UIColor.systemGroupedBackground)
                )
                DiffScrollViewControllerRepresentable(
                    entries: interleaveComments(
                        entries: expandDiffLines(diff),
                        comments: comments
                    )
                )
            }
        }
    }
}
