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
    case skippedLines(beforeStart: Int, afterStart: Int, count: Int, lines: [String]?)
    case comments(CommentThread)
}

// Expands DiffInfo chunks into a linear list of rendered entries, tracking
// line numbers on both sides (before = PARENT, after = REVISION). Unchanged
// stretches farther than `context` lines away from any edit are collapsed;
// their lines ship with the entry, as current Gerrit servers return the whole
// file in the diff. Regions collapsed by the server (`skip` chunks) have no
// local lines and fetch their content on demand.
func expandDiffLines(_ diff: DiffInfo, context: Int = 10) -> [DiffEntry] {
    struct Row {
        let beforeNumber: Int?
        let afterNumber: Int?
        let text: String
        let skip: Int?
        let pinned: Bool
    }

    var rows: [Row] = []
    var before = 0
    var after = 0
    for chunk in diff.content {
        if let skip = chunk.skip {
            rows.append(Row(
                beforeNumber: before + 1,
                afterNumber: after + 1,
                text: "",
                skip: skip,
                pinned: true
            ))
            before += skip
            after += skip
            continue
        }
        let aLines = chunk.a ?? []
        let bLines = chunk.b ?? []
        let abLines = chunk.ab ?? []
        let rowCount = max(aLines.count, bLines.count, abLines.count)
        for i in 0..<rowCount {
            if i < abLines.count {
                before += 1
                after += 1
                rows.append(Row(
                    beforeNumber: before,
                    afterNumber: after,
                    text: abLines[i],
                    skip: nil,
                    pinned: false
                ))
            } else {
                if i < aLines.count {
                    before += 1
                    rows.append(Row(
                        beforeNumber: before,
                        afterNumber: nil,
                        text: aLines[i],
                        skip: nil,
                        pinned: true
                    ))
                }
                if i < bLines.count {
                    after += 1
                    rows.append(Row(
                        beforeNumber: nil,
                        afterNumber: after,
                        text: bLines[i],
                        skip: nil,
                        pinned: true
                    ))
                }
            }
        }
    }

    var visible = Array(repeating: false, count: rows.count)
    for (i, row) in rows.enumerated() where row.pinned {
        for j in max(0, i - context)...min(rows.count - 1, i + context) {
            visible[j] = true
        }
    }

    var entries: [DiffEntry] = []
    var run: [Row] = []
    func flushRun() {
        guard let first = run.first, let beforeStart = first.beforeNumber, let afterStart = first.afterNumber else {
            run = []
            return
        }
        entries.append(.skippedLines(
            beforeStart: beforeStart,
            afterStart: afterStart,
            count: run.count,
            lines: run.map { $0.text }
        ))
        run = []
    }
    for (i, row) in rows.enumerated() {
        if visible[i] {
            flushRun()
            if let skip = row.skip {
                entries.append(.skippedLines(
                    beforeStart: row.beforeNumber!,
                    afterStart: row.afterNumber!,
                    count: skip,
                    lines: nil
                ))
            } else {
                entries.append(.line(DiffLine(
                    beforeNumber: row.beforeNumber,
                    afterNumber: row.afterNumber,
                    text: row.text
                )))
            }
        } else {
            run.append(row)
        }
    }
    flushRun()
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

// Comments belonging to the current patch set, unless older ones were
// requested. Comments without a patch set count as current; file entries
// left without comments are dropped.
func commentsForPatchSet(_ commentsByFile: [String: [CommentInfo]], current: Int?, showOlder: Bool) -> [String: [CommentInfo]] {
    if showOlder || current == nil {
        return commentsByFile
    }
    return commentsByFile.mapValues { comments in
            comments.filter { $0.patchSet == nil || $0.patchSet == current }
        }
        .filter { !$0.value.isEmpty }
}

// Whether comments from patch sets older than `current` exist.
func hasOlderPatchsetComments(_ commentsByFile: [String: [CommentInfo]], current: Int?) -> Bool {
    guard let current else { return false }
    return commentsByFile.values.contains { comments in
        comments.contains { comment in
            (comment.patchSet ?? current) < current
        }
    }
}

// Change messages belonging to the current patch set, unless older ones
// were requested. Messages without a revision number count as current.
func messagesForPatchSet(_ messages: [ChangeMessageInfo], current: Int?, showOlder: Bool) -> [ChangeMessageInfo] {
    if showOlder || current == nil {
        return messages
    }
    return messages.filter { $0.revisionNumber == nil || $0.revisionNumber == current }
}

// Whether change messages from patch sets older than `current` exist.
func hasOlderPatchsetMessages(_ messages: [ChangeMessageInfo], current: Int?) -> Bool {
    guard let current else { return false }
    return messages.contains { ($0.revisionNumber ?? current) < current }
}

extension CommentInfo {
    // A file comment has neither a line nor a range (or line 0, as used by drafts).
    var isFileComment: Bool {
        return endLine == nil || endLine == 0
    }

    // The map form of the comments response keeps the path in the map keys,
    // so it is attached to every comment here.
    func withPath(_ path: String) -> CommentInfo {
        return CommentInfo(
            id: id,
            patchSet: patchSet,
            path: path,
            side: side,
            parentNumber: parentNumber,
            line: line,
            range: range,
            inReplyTo: inReplyTo,
            message: message,
            updated: updated,
            author: author,
            tag: tag,
            unresolved: unresolved,
            changeMessageId: changeMessageId
        )
    }
}

// Groups the published inline comments by the change message that published
// them; the server links every comment to its message. Threads without a
// linked message are not shown in the timeline.
func threadsForChangeMessages(_ commentsByFile: [String: [CommentInfo]]) -> [String: [CommentThread]] {
    var byMessage: [String: [CommentInfo]] = [:]
    for (path, comments) in commentsByFile {
        for comment in comments {
            guard let messageId = comment.changeMessageId else {
                continue
            }
            byMessage[messageId, default: []].append(comment.withPath(path))
        }
    }
    return byMessage.mapValues { groupCommentThreads($0) }
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
        case .skippedLines(let beforeStart, let afterStart, let count, _):
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
