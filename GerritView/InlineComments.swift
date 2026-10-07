import Foundation

enum DiffLineSide {
    case before
    case after
}

struct DiffLine: Equatable {
    let beforeNumber: Int?
    let afterNumber: Int?
    let text: String
}

struct CommentThread: Equatable {
    let comments: [CommentInfo]
}

enum DiffEntry: Equatable {
    case line(DiffLine)
    case skippedLines(beforeStart: Int, afterStart: Int, count: Int)
    case comments(CommentThread)
}

// Expands DiffInfo chunks into a linear list of rendered entries, tracking
// line numbers on both sides (before = PARENT, after = REVISION).
func expandDiffLines(_ diff: DiffInfo) -> [DiffEntry] {
    var entries: [DiffEntry] = []
    var before = 0
    var after = 0
    for chunk in diff.content {
        if let skip = chunk.skip {
            entries.append(.skippedLines(
                beforeStart: before + 1,
                afterStart: after + 1,
                count: skip
            ))
            before += skip
            after += skip
            continue
        }
        let aLines = chunk.a ?? []
        let bLines = chunk.b ?? []
        let abLines = chunk.ab ?? []
        let rows = max(aLines.count, bLines.count, abLines.count)
        for i in 0..<rows {
            if i < abLines.count {
                before += 1
                after += 1
                entries.append(.line(DiffLine(
                    beforeNumber: before,
                    afterNumber: after,
                    text: abLines[i]
                )))
            } else {
                if i < aLines.count {
                    before += 1
                    entries.append(.line(DiffLine(
                        beforeNumber: before,
                        afterNumber: nil,
                        text: aLines[i]
                    )))
                }
                if i < bLines.count {
                    after += 1
                    entries.append(.line(DiffLine(
                        beforeNumber: nil,
                        afterNumber: after,
                        text: bLines[i]
                    )))
                }
            }
        }
    }
    return entries
}

// Groups comments into reply threads. Comments whose in_reply_to points to
// a comment not in the input (e.g. a change message) become their own root.
func groupCommentThreads(_ comments: [CommentInfo]) -> [CommentThread] {
    var children: [String: [CommentInfo]] = [:]
    var roots: [CommentInfo] = []
    let byId = Dictionary(uniqueKeysWithValues: comments.map { ($0.id, $0) })
    for comment in comments {
        if let parent = comment.inReplyTo, byId[parent] != nil {
            children[parent, default: []].append(comment)
        } else {
            roots.append(comment)
        }
    }

    func collect(id: String) -> [CommentInfo] {
        var result: [CommentInfo] = []
        for child in children[id] ?? [] {
            result.append(child)
            result.append(contentsOf: collect(id: child.id))
        }
        return result
    }

    func chronologically(_ a: CommentInfo, _ b: CommentInfo) -> Bool {
        return a.updated == b.updated ? a.id < b.id : a.updated < b.updated
    }

    return roots.sorted(by: chronologically).map { root in
        CommentThread(comments: ([root] + collect(id: root.id)).sorted(by: chronologically))
    }
}

extension CommentInfo {
    // A file comment has neither a line nor a range (or line 0, as used by drafts).
    var isFileComment: Bool {
        return endLine == nil || endLine == 0
    }
}

// The parent commit the comments belong to, for merge commits. Comments on
// the revision side or the auto-merge tree need no specific parent diff.
func diffParentNumber(for comments: [CommentInfo]) -> Int? {
    for comment in comments where comment.effectiveSide == .parent {
        if let parent = comment.parentNumber {
            return parent
        }
    }
    return nil
}

extension CommentThread {
    // The comment that anchors the thread's position in the diff.
    var anchor: CommentInfo? {
        return comments.first
    }
}

// Returns the insertion position for a thread: 0 = top of file,
// i in 1...count = right after rendered entry i-1, count = end of diff.
func anchorPosition(for thread: CommentThread, in entries: [DiffEntry]) -> Int {
    guard let anchor = thread.anchor, !anchor.isFileComment else {
        return 0
    }
    let endLine = anchor.endLine!
    let side: DiffLineSide = anchor.effectiveSide == .parent ? .before : .after

    for (i, entry) in entries.enumerated() {
        switch entry {
        case .line(let line):
            let matches = side == .before
                ? line.beforeNumber == endLine
                : line.afterNumber == endLine
            if matches {
                return i + 1
            }
        case .skippedLines(let beforeStart, let afterStart, let count):
            let start = side == .before ? beforeStart : afterStart
            if endLine >= start && endLine < start + count {
                return i + 1
            }
        case .comments:
            continue
        }
    }
    // Line not present in the rendered diff (e.g. beyond it): show at the end.
    return entries.count
}

func interleaveComments(entries: [DiffEntry], comments: [CommentInfo]) -> [DiffEntry] {
    var insertions: [Int: [CommentThread]] = [:]
    for thread in groupCommentThreads(comments) {
        let position = anchorPosition(for: thread, in: entries)
        insertions[position, default: []].append(thread)
    }

    var result: [DiffEntry] = []
    if let threads = insertions[0] {
        result.append(contentsOf: threads.map { DiffEntry.comments($0) })
    }
    for (i, entry) in entries.enumerated() {
        result.append(entry)
        if let threads = insertions[i + 1] {
            result.append(contentsOf: threads.map { DiffEntry.comments($0) })
        }
    }
    return result
}
