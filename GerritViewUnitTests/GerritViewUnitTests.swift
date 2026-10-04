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
