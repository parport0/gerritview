import SwiftUI

struct ChangeDiffView: View {
    let changeId: String
    let revisionId: String
    let fileId: String
    let commentsByFile: [String: [CommentInfo]]
    var olderCommentsByFile: [String: [CommentInfo]] = [:]
    var paths: [String] = []

    @State private var activeFileId: String? = nil
    @State private var gerritDiffModel = GerritFileDiffViewModel()
    @Environment(Settings.self) var settings: Settings

    private var activeFile: String {
        return activeFileId ?? fileId
    }

    private var comments: [CommentInfo] {
        return commentsByFile[activeFile] ?? []
    }

    private var olderComments: [CommentInfo] {
        return olderCommentsByFile[activeFile] ?? []
    }

    private var fileIndex: Int? {
        return paths.firstIndex(of: activeFile)
    }

    var body: some View {
        Group {
            switch gerritDiffModel.state {
            case .empty:
                ProgressView()
                    .task {
                        await self.gerritDiffModel
                            .fetchDiff(
                                settings: settings,
                                changeId: changeId,
                                revisionId: String(revisionId),
                                fileId: activeFile,
                                parentNumber: diffParentNumber(for: comments)
                            )
                    }
            case .failed(let error):
                Text(error.localizedDescription)
            case .loaded(let diff):
                ScrollView {
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
                        DiffContentView(
                            entries: expandDiffLines(diff),
                            comments: comments,
                            olderComments: olderComments,
                            changeId: changeId,
                            revisionId: revisionId,
                            fileId: activeFile
                        )
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    if let index = fileIndex, index > 0 {
                        activeFileId = paths[index - 1]
                    }
                } label: {
                    Image(systemName: "arrow.left")
                }
                .disabled(paths.count < 2 || fileIndex == nil || fileIndex == 0)

                Button {
                    if let index = fileIndex, index < paths.count - 1 {
                        activeFileId = paths[index + 1]
                    }
                } label: {
                    Image(systemName: "arrow.right")
                }
                .disabled(paths.count < 2 || fileIndex == nil || fileIndex == paths.count - 1)
            }
        }
        .onChange(of: activeFileId) { _, _ in
            gerritDiffModel = GerritFileDiffViewModel()
        }
    }
}

struct DiffContentView: View {
    let entries: [DiffEntry]
    let comments: [CommentInfo]
    var olderComments: [CommentInfo] = []
    let changeId: String
    let revisionId: String
    let fileId: String

    // Threads from older patch sets whose anchor line is no longer part of
    // the rendered diff.
    private func lostThreads() -> [CommentThread] {
        return groupCommentThreads(olderComments).filter {
            anchorLinePosition(for: $0, in: entries) == nil
        }
    }

    var body: some View {
        let lost = lostThreads()
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(
                Array(interleaveComments(
                    entries: entries,
                    comments: comments,
                    olderThreads: groupCommentThreads(olderComments)
                ).enumerated()),
                id: \.offset
            ) { _, entry in
                switch entry {
                case .line(let line):
                    DiffLineRow(line: line)
                case .skippedLines(let beforeStart, let afterStart, let count, let localLines):
                    SkippedLinesRow(
                        beforeStart: beforeStart,
                        afterStart: afterStart,
                        count: count,
                        localLines: localLines,
                        changeId: changeId,
                        revisionId: revisionId,
                        fileId: fileId
                    )
                case .comments(let thread):
                    CommentThreadRow(
                        thread: thread,
                        note: lost.contains(thread)
                            ? "Original comment position not found in this patchset"
                            : nil
                    )
                }
            }
        }
    }
}

struct DiffLineRow: View {
    let line: DiffLine

    private var color: Color {
        switch (line.beforeNumber, line.afterNumber) {
        case (.some, .none):
            return Color(red: 0.7, green: 0.3, blue: 0.3)
        case (.none, .some):
            return Color(red: 0.3, green: 0.7, blue: 0.3)
        default:
            return .primary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            lineNumber(line.beforeNumber)
            lineNumber(line.afterNumber)
            Text(line.text.isEmpty ? " " : line.text)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func lineNumber(_ number: Int?) -> some View {
        return Group {
            if let number {
                Text(String(number))
            } else {
                Text(" ")
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(width: 40, alignment: .trailing)
    }
}

struct SkippedLinesRow: View {
    let beforeStart: Int
    let afterStart: Int
    let count: Int
    let localLines: [String]?
    let changeId: String
    let revisionId: String
    let fileId: String
    @Environment(Settings.self) var settings: Settings
    @State private var expanded = false
    @State private var lines: [String]? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        let resolvedLines = localLines ?? lines
        Group {
        if expanded {
            if let resolvedLines {
                ForEach(Array(resolvedLines.enumerated()), id: \.offset) { i, text in
                    DiffLineRow(line: DiffLine(
                        beforeNumber: beforeStart + i,
                        afterNumber: afterStart + i,
                        text: text
                    ))
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(4)
            } else {
                ProgressView()
                    .padding(4)
            }
            Button {
                expanded = false
            } label: {
                Text("· · · collapse · · ·")
                    .font(.system(.footnote, design: .monospaced))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        } else {
            Button {
                expanded = true
                if resolvedLines == nil && errorMessage == nil {
                    Task {
                        await fetchHiddenLines()
                    }
                }
            } label: {
                Text("· · · \(count) hidden lines · · ·")
                    .font(.system(.footnote, design: .monospaced))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        }
    }

    // Hidden regions are unchanged code, so the revision-side content covers
    // both sides; only the line numbers differ.
    private func fetchHiddenLines() async {
        if localLines != nil || lines != nil || errorMessage != nil {
            return
        }
        do {
            let url = composeFileContentGerritUrl(
                settings: settings,
                change: changeId,
                revisionId: revisionId,
                fileId: fileId
            )
            let data = try await fetchGerritData(from: url)
            guard let slice = fileContentLines(from: data, start: afterStart, count: count) else {
                errorMessage = "The file content could not be decoded."
                return
            }
            lines = slice
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CommentThreadRow: View {
    let thread: CommentThread
    var note: String? = nil

    private func place(_ comment: CommentInfo) -> String {
        if comment.path == "/PATCHSET_LEVEL" {
            return ""
        }
        var parts: [String] = []
        if let path = comment.path {
            parts.append(path)
        }
        if comment.isFileComment {
            parts.append("file")
        } else {
            let side = comment.effectiveSide == .parent
                ? (comment.parentNumber.map { "parent \($0)" } ?? "before")
                : "after"
            parts.append("\(side) line \(comment.endLine ?? 0)")
        }
        return parts.joined(separator: " ")
    }

    var body: some View {
        let background: Color = (thread.comments.last?.unresolved ?? false)
            ? Color.yellow.opacity(0.25)
            : Color(uiColor: .secondarySystemBackground)
        VStack(alignment: .leading, spacing: 4) {
            if let note {
                HStack(spacing: 2) {
                    Image(systemName: "info")
                    Text(note)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            ForEach(thread.comments, id: \.id) { comment in
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        UserpicView(account: comment.author, size: 14)
                        if comment.unresolved == true {
                            Text("●").font(.footnote).foregroundStyle(.orange)
                        }
                        Text(comment.author?.Name() ?? "Unknown").font(.footnote)
                        if let patchSet = comment.patchSet {
                            Text("PS\(patchSet)").font(.footnote).foregroundStyle(.secondary)
                        }
                        if !place(comment).isEmpty {
                            Text(place(comment)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Text(verbatim: comment.message ?? "").font(.footnote)
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .padding(.vertical, 4)
    }
}
