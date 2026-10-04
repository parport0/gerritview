//
//  GerritViewUnitTests.swift
//  GerritViewUnitTests
//
//  Created by liney on 2026-03-22.
//

import Testing
@testable import GerritView

struct GerritApiTests {
    let revisionCommentsJson = """
    )]}'
    {
      "gerrit-server/src/main/java/com/google/gerrit/server/project/RefControl.java": [
        {
          "patch_set": 1,
          "id": "TvcXrmjM",
          "line": 23,
          "updated": "2013-02-26 15:40:43.986000000",
          "message": "What is the purpose of this line?",
          "author": {
            "_account_id": 1000002,
            "name": "Alice"
          }
        },
        {
          "id": "TveXwFiA",
          "line": 49,
          "in_reply_to": "TfYX-Iuo",
          "side": "PARENT",
          "range": {
            "start_line": 49,
            "start_character": 0,
            "end_line": 51,
            "end_character": 12
          },
          "unresolved": true,
          "updated": "2013-02-26 15:40:45.328000000",
          "message": "Done"
        }
      ],
      "unchanged/File.java": [
        {
          "id": "TaXzYqZ",
          "updated": "2013-02-25 10:00:00.000000000",
          "message": "File-level comment without line or range"
        }
      ]
    }
    """

    @Test func decodeRevisionComments() throws {
        let commentsByFile = try decodeGerritRevisionCommentsResponse(
            from: revisionCommentsJson
        )

        #expect(commentsByFile.count == 2)
        let comments = commentsByFile["gerrit-server/src/main/java/com/google/gerrit/server/project/RefControl.java"]!
        #expect(comments.count == 2)

        let first = comments[0]
        #expect(first.id == "TvcXrmjM")
        #expect(first.patchSet == 1)
        #expect(first.line == 23)
        #expect(first.range == nil)
        #expect(first.author?.Name() == "Alice")
        #expect(first.effectiveSide == .revision)

        let second = comments[1]
        #expect(second.inReplyTo == "TfYX-Iuo")
        #expect(second.effectiveSide == .parent)
        #expect(second.range?.endLine == 51)
        #expect(second.endLine == 51)
        #expect(second.unresolved == true)
        #expect(second.author == nil)

        let fileComment = commentsByFile["unchanged/File.java"]![0]
        #expect(fileComment.line == nil)
        #expect(fileComment.range == nil)
        #expect(fileComment.endLine == nil)
        #expect(fileComment.effectiveSide == .revision)
    }

    @Test func decodeEmptyRevisionComments() throws {
        let commentsByFile = try decodeGerritRevisionCommentsResponse(
            from: ")]}'\n{}\n"
        )
        #expect(commentsByFile.isEmpty)
    }
}

struct InlineCommentsTests {
    func comment(
        id: String,
        line: Int? = nil,
        range: CommentRange? = nil,
        side: CommentSide? = nil,
        reply: String? = nil,
        updated: String = "2024-01-01 10:00:00.000000000",
        message: String = "msg"
    ) -> CommentInfo {
        return CommentInfo(
            id: id,
            patchSet: 1,
            path: nil,
            side: side,
            parentNumber: nil,
            line: line,
            range: range,
            inReplyTo: reply,
            message: message,
            updated: updated,
            author: nil,
            tag: nil,
            unresolved: nil
        )
    }

    func diff(_ chunks: [DiffContent]) -> DiffInfo {
        return DiffInfo(
            metaA: nil,
            metaB: nil,
            changeType: .modified,
            intralineStatus: nil,
            diffHeader: [],
            content: chunks,
            webLinks: nil,
            editWebLinks: nil,
            binary: nil
        )
    }

    @Test func expandMixedDiff() {
        let chunks = [
            DiffContent(a: nil, b: nil, ab: ["l1", "l2"], dueToRebase: nil, dueToMove: nil, skip: nil, common: nil),
            DiffContent(a: ["d1"], b: ["n1"], ab: nil, dueToRebase: nil, dueToMove: nil, skip: nil, common: nil),
            DiffContent(a: nil, b: nil, ab: nil, dueToRebase: nil, dueToMove: nil, skip: 5, common: nil)
        ]
        let entries = expandDiffLines(diff(chunks))

        #expect(entries == [
            .line(DiffLine(beforeNumber: 1, afterNumber: 1, text: "l1")),
            .line(DiffLine(beforeNumber: 2, afterNumber: 2, text: "l2")),
            .line(DiffLine(beforeNumber: 3, afterNumber: nil, text: "d1")),
            .line(DiffLine(beforeNumber: nil, afterNumber: 3, text: "n1")),
            .skippedLines(beforeStart: 4, afterStart: 4, count: 5)
        ])
    }

    func ab(_ lines: [String]) -> DiffContent {
        return DiffContent(a: nil, b: nil, ab: lines, dueToRebase: nil, dueToMove: nil, skip: nil, common: nil)
    }

    @Test func expandUnchangedFile() {
        let entries = expandDiffLines(diff([ab(["a", "b", "c"])]))
        #expect(entries == [
            .line(DiffLine(beforeNumber: 1, afterNumber: 1, text: "a")),
            .line(DiffLine(beforeNumber: 2, afterNumber: 2, text: "b")),
            .line(DiffLine(beforeNumber: 3, afterNumber: 3, text: "c"))
        ])
    }

    @Test func commentPlacementRespectsSide() {
        let entries = expandDiffLines(diff([
            DiffContent(a: ["a1", "a2", "a3"], b: ["b1", "b2", "b3"], ab: nil, dueToRebase: nil, dueToMove: nil, skip: nil, common: nil)
        ]))
        let comments = [
            comment(id: "r", line: 2, side: .revision, message: "on b2"),
            comment(id: "p", line: 2, side: .parent, message: "on a2")
        ]
        let result = interleaveComments(entries: entries, comments: comments)

        // Parent-side comment goes right after the "a2" line (index 2),
        // revision-side comment right after the "b2" line (index 3).
        #expect(result.compactMap { commentId(of: $0) } == ["p", "r"])
        #expect(result.count == 8)
        #expect(result[3].thread?.comments[0].message == "on a2")
        #expect(result[5].thread?.comments[0].message == "on b2")
    }

    @Test func fileCommentGoesToTop() {
        let entries = expandDiffLines(diff([ab(["a", "b"])]))
        let result = interleaveComments(entries: entries, comments: [
            comment(id: "f", message: "file-level")
        ])
        #expect(result.count == 3)
        #expect(commentId(of: result[0]) == "f")
        #expect(result[0].thread?.comments[0].message == "file-level")
    }

    @Test func commentInsideSkippedRegionAnchorsToPlaceholder() {
        let entries = expandDiffLines(diff([
            ab(["l1"]),
            DiffContent(a: nil, b: nil, ab: nil, dueToRebase: nil, dueToMove: nil, skip: 10, common: nil),
            ab(["l12"])
        ]))
        let result = interleaveComments(entries: entries, comments: [
            comment(id: "s", line: 7)
        ])
        // Placeholder is entry index 1, so the comment lands at index 2.
        #expect(commentId(of: result[2]) == "s")
    }

    @Test func commentOnLineOutsideDiffGoesToEnd() {
        let entries = expandDiffLines(diff([ab(["l1", "l2"])]))
        let result = interleaveComments(entries: entries, comments: [
            comment(id: "x", line: 100)
        ])
        #expect(commentId(of: result.last!) == "x")
    }

    @Test func rangeEndLineAnchorsComment() {
        let entries = expandDiffLines(diff([ab(["l1", "l2", "l3"])]))
        let range = CommentRange(
            startLine: 1,
            startCharacter: 0,
            endLine: 2,
            endCharacter: 5
        )
        let result = interleaveComments(entries: entries, comments: [
            comment(id: "rg", range: range)
        ])
        #expect(commentId(of: result[2]) == "rg")
    }

    @Test func repliesGroupIntoThreads() {
        let comments = [
            comment(id: "c1", line: 3, updated: "2024-01-01 10:00:00.000000000"),
            comment(id: "c3", reply: "c1", updated: "2024-01-02 10:00:00.000000000"),
            comment(id: "c2", reply: "c1", updated: "2024-01-01 11:00:00.000000000"),
            comment(id: "orphan", line: 1, reply: "missing-id")
        ]
        let threads = groupCommentThreads(comments)

        #expect(threads.count == 2)
        let c1Thread = threads.first { $0.comments[0].id == "c1" }!
        #expect(c1Thread.comments.map { $0.id } == ["c1", "c2", "c3"])
        let orphanThread = threads.first { $0.comments[0].id == "orphan" }!
        #expect(orphanThread.comments.count == 1)
    }

    @Test func unchangedFileCommentsOnBothSides() {
        let entries = expandDiffLines(diff([ab(["a", "b", "c"])]))
        let comments = [
            comment(id: "after", line: 2, side: .revision, updated: "2024-01-01 10:05:00.000000000"),
            comment(id: "before", line: 2, side: .parent, updated: "2024-01-01 10:00:00.000000000")
        ]
        let result = interleaveComments(entries: entries, comments: comments)

        // Both anchors match the same ab line ("b", entry index 1); they end up adjacent after it.
        #expect(result.count == 5)
        #expect(commentId(of: result[2]) == "before")
        #expect(commentId(of: result[3]) == "after")
    }
}

extension DiffEntry {
    var thread: CommentThread? {
        if case .comments(let t) = self {
            return t
        }
        return nil
    }
}

func commentId(of entry: DiffEntry) -> String? {
    return entry.thread?.comments.first?.id
}
