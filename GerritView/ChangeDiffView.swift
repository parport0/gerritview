import SwiftUI

enum diffContentSide {
    case deleted
    case added
    case unchanged
}

class DiffScrollViewController: UIViewController {
    @Binding var model: GerritFileDiffViewModel

    var textView: UITextView = UITextView()

    init(model: Binding<GerritFileDiffViewModel>) {
        self._model = model
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func generateTextView() -> UITextView {
        let summedText: NSMutableAttributedString = NSMutableAttributedString()

        switch model.state {
        case .loaded(let diff):
            for c in diff.content {
                if c.a != nil {
                    summedText.append(
                        NSAttributedString(
                            string: c.a!.joined(separator: "\n") + "\n",
                            attributes: [
                                         .font: UIFont.monospacedSystemFont(
                                            ofSize: UIFont.smallSystemFontSize,
                                            weight: .medium
                                         ),
                                         .foregroundColor: UIColor.init(
                                            red: 0.7,
                                            green: 0.3,
                                            blue: 0.3,
                                            alpha: 1.0)]
                        )
                    )
                }
                if c.b != nil {
                    summedText.append(
                        NSAttributedString(
                            string: c.b!.joined(separator: "\n") + "\n",
                            attributes: [
                                .font: UIFont.monospacedSystemFont(
                                            ofSize: UIFont.smallSystemFontSize,
                                            weight: .medium
                                         ),
                                         .foregroundColor: UIColor.init(
                                            red: 0.3,
                                            green: 0.7,
                                            blue: 0.3,
                                            alpha: 1.0
                                         )
                                ]
                        )
                    )
                }
                if c.ab != nil {
                    summedText.append(
                        NSAttributedString(
                            string: c.ab!.joined(separator: "\n") + "\n",
                            attributes: [.font: UIFont.monospacedSystemFont(
                                            ofSize: UIFont.smallSystemFontSize,
                                            weight: .medium
                            ), .foregroundColor: UIColor.black]
                        )
                    )
                }
            }
        default: break
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
        self.textView = generateTextView()
        view.addSubview(self.textView)
        self.textView.frame = view.frame
    }
}

struct DiffScrollViewControllerRepresentable: UIViewControllerRepresentable {
    @Binding var model: GerritFileDiffViewModel
    typealias UIViewControllerType = UIViewController

    var controller: UIViewController

    init(model: Binding<GerritFileDiffViewModel>) {
        self._model = model
        controller = DiffScrollViewController(model: self._model)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let size = controller.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        controller.preferredContentSize = size

        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}

    class Coordinator: NSObject {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

}

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
                DiffScrollViewControllerRepresentable(model: $gerritDiffModel)
            }

        }
    }
}
