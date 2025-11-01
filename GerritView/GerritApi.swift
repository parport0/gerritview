import SwiftUI

public struct GerritChange: Codable, Identifiable, Equatable {
    public let id: String
    let project: String
    let branch: String
    let topic: String?
    let attentionSet: [String: AttentionSetEntry]?
    let removedFromAttentionSet: [String: AttentionSetEntry]?
    let assignee: AccountInfo?
    let hashtags: [String]?
    let changeId: String
    var subject: String
    let status: ChangeStatus
    let created: String
    let updated: String
    let submitted: String?
    let submitter: AccountInfo?
    let starred: Bool?
    let stars: [String]?
    let reviewed: Bool?
    let submitType: SubmitType?
    let mergeable: Bool?
    let submittable: Bool?
    let insertions: Int?
    let deletions: Int?
    let totalCommentCount: Int?
    let unresolvedCommentCount: Int?
    let hasReviewStarted: Bool?
    let number: Int
    let owner: AccountInfo
    let actions: [String: ActionInfo]?
    let labels: [String: LabelInfo]?
    let permittedLabels: [String: [String]]?
    let reviewers: ReviewersInfo?
    let reviewerUpdates: [ReviewerUpdateInfo]?
    var messages: [ChangeMessageInfo]?
    let currentRevision: String?
    let revisions: [String: RevisionInfo]?
    let trackingIds: [TrackingIdInfo]?
    let moreChanges: Bool?
    let problems: [ProblemInfo]?
    let isPrivate: Bool?
    let workInProgress: Bool?
    let hasReviewStartedCount: Int?
    let revertOf: Int?
    let submissionId: String?
    let cherryPickOfChange: Int?
    let cherryPickOfPatchSet: Int?
    let containsGitConflicts: Bool?
    let requirements: [Requirement]?
    let submitRequirements: [SubmitRequirementResultInfo]?
    let submitRecords: [SubmitRecord]?
    let tripletId: String
    let virtualIdNumber: Int?
    let currentRevisionNumber: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case project
        case branch
        case topic
        case attentionSet = "attention_set"
        case removedFromAttentionSet = "removed_from_attention_set"
        case assignee
        case hashtags
        case changeId = "change_id"
        case subject
        case status
        case created
        case updated
        case submitted
        case submitter
        case starred
        case stars
        case reviewed
        case submitType = "submit_type"
        case mergeable
        case submittable
        case insertions
        case deletions
        case totalCommentCount = "total_comment_count"
        case unresolvedCommentCount = "unresolved_comment_count"
        case hasReviewStarted = "has_review_started"
        case number = "_number"
        case owner
        case actions
        case labels
        case permittedLabels = "permitted_labels"
        case reviewers
        case reviewerUpdates = "reviewer_updates"
        case messages
        case currentRevision = "current_revision"
        case revisions
        case trackingIds = "tracking_ids"
        case moreChanges = "_more_changes"
        case problems
        case isPrivate = "is_private"
        case workInProgress = "work_in_progress"
        case hasReviewStartedCount = "has_review_started_count"
        case revertOf = "revert_of"
        case submissionId = "submission_id"
        case cherryPickOfChange = "cherry_pick_of_change"
        case cherryPickOfPatchSet = "cherry_pick_of_patchset"
        case containsGitConflicts = "contains_git_conflicts"
        case requirements
        case submitRequirements = "submit_requirements"
        case submitRecords = "submit_records"
        case tripletId = "triplet_id"
        case virtualIdNumber = "virtual_id_number"
        case currentRevisionNumber = "current_revision_number"
    }
    
    public static func ==(l: GerritChange, r: GerritChange) -> Bool {
        return (r.id == l.id)
    }
}

public enum ChangeStatus: String, Codable {
    case new = "NEW"
    case merged = "MERGED"
    case abandoned = "ABANDONED"
}

public enum SubmitType: String, Codable {
    case mergeIfNecessary = "MERGE_IF_NECESSARY"
    case fastForwardOnly = "FAST_FORWARD_ONLY"
    case rebaseIfNecessary = "REBASE_IF_NECESSARY"
    case rebaseAlways = "REBASE_ALWAYS"
    case mergeAlways = "MERGE_ALWAYS"
    case cherryPick = "CHERRY_PICK"
}

public struct AttentionSetEntry: Codable {
    let account: AccountInfo
    let lastUpdate: String
    let reason: String
    let reasonAccount: AccountInfo?
    
    enum CodingKeys: String, CodingKey {
        case account
        case lastUpdate = "last_update"
        case reason
        case reasonAccount = "reason_account"
    }
}

public struct AccountInfo: Codable {
    let accountId: Int?
    let name: String?
    let displayName: String?
    let email: String?
    let secondaryEmails: [String]?
    let username: String?
    let avatars: [AvatarInfo]?
    let moreAccounts: Bool?
    let status: String?
    let inactive: Bool?
    let tags: [String]?
    
    func Name() -> String {
        return displayName ?? name ?? username ?? name ?? String(accountId ?? 0)
    }
    
    enum CodingKeys: String, CodingKey {
        case accountId = "_account_id"
        case name
        case displayName = "display_name"
        case email
        case secondaryEmails = "secondary_emails"
        case username
        case avatars
        case moreAccounts = "_more_accounts"
        case status
        case inactive
        case tags
    }
}

public struct AvatarInfo: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

public struct ActionInfo: Codable {
    let method: String?
    let label: String?
    let title: String?
    let enabled: Bool?
}

public struct LabelInfo: Codable {
    let optional: Bool?
    let approved: AccountInfo?
    let rejected: AccountInfo?
    let recommended: AccountInfo?
    let disliked: AccountInfo?
    let blocking: Bool?
    let value: Int?
    let defaultValue: Int?
    let values: [String: String]?
    let all: [ApprovalInfo]?
    
    enum CodingKeys: String, CodingKey {
        case optional
        case approved
        case rejected
        case recommended
        case disliked
        case blocking
        case value
        case defaultValue = "default_value"
        case values
        case all
    }
}

public struct ApprovalInfo: Codable {
    let accountId: Int?
    let name: String?
    let email: String?
    let username: String?
    let approved: Bool?
    let value: Int?
    let permittedVotingRange: VotingRangeInfo?
    let date: String?
    let tag: String?
    let postSubmit: Bool?
    
    enum CodingKeys: String, CodingKey {
        case accountId = "_account_id"
        case name
        case email
        case username
        case approved
        case value
        case permittedVotingRange = "permitted_voting_range"
        case date
        case tag
        case postSubmit = "post_submit"
    }
}

public struct VotingRangeInfo: Codable {
    let min: Int
    let max: Int
}

public struct ReviewersInfo: Codable {
    let reviewers: [AccountInfo]?
    let cc: [AccountInfo]?
    
    enum CodingKeys: String, CodingKey {
        case reviewers = "REVIEWER"
        case cc = "CC"
    }
}

public struct ReviewerUpdateInfo: Codable {
    let updated: String
    let updatedBy: AccountInfo
    let reviewer: AccountInfo
    let state: ReviewerState
    
    enum CodingKeys: String, CodingKey {
        case updated
        case updatedBy = "updated_by"
        case reviewer
        case state
    }
}

public enum ReviewerState: String, Codable {
    case reviewer = "REVIEWER"
    case cc = "CC"
    case removed = "REMOVED"
}

public struct ChangeMessageInfo: Codable, Identifiable {
    public let id: String
    let author: AccountInfo?
    let realAuthor: AccountInfo?
    let date: Date
    let message: String
    let tag: String?
    let revisionNumber: Int?
    var attributedMessage: AttributedString?  // for a post-processed comment
    
    enum CodingKeys: String, CodingKey {
        case id
        case author
        case realAuthor = "real_author"
        case date
        case message
        case tag
        case revisionNumber = "_revision_number"
        case attributedMessage
    }
}

public struct RevisionInfo: Codable {
    let kind: String
    let number: Int
    let created: String
    let uploader: AccountInfo
    let realUploader: AccountInfo?
    let ref: String
    let fetch: [String: FetchInfo]?
    let commit: CommitInfo?
    let branch: String?
    let files: [String: FileInfo]?
    let actions: [String: ActionInfo]?
    let reviewed: Bool?
    let commitWithFooters: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case kind
        case number = "_number"
        case created
        case uploader
        case realUploader = "real_uploader"
        case ref
        case fetch
        case commit
        case branch
        case files
        case actions
        case reviewed
        case commitWithFooters = "commit_with_footers"
        case description
    }
}

public struct FetchInfo: Codable {
    let url: String
    let ref: String
    let commands: [String: String]?
}

public struct CommitInfo: Codable {
    let commit: String?
    let parents: [CommitInfo]?
    let author: GitPersonInfo?
    let committer: GitPersonInfo?
    let subject: String
    var message: String?
    let webLinks: [WebLinkInfo]?
    
    enum CodingKeys: String, CodingKey {
        case commit
        case parents
        case author
        case committer
        case subject
        case message
        case webLinks = "web_links"
    }
}

public struct GitPersonInfo: Codable {
    let name: String
    let email: String
    let date: String
    let tz: Int
}

public struct WebLinkInfo: Codable {
    let name: String
    let url: String
    let imageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case imageUrl = "image_url"
    }
}

public struct FileInfo: Codable, Identifiable {
    public let id = UUID()
    let status: String?
    let binary: Bool?
    let oldPath: String?
    let linesInserted: Int?
    let linesDeleted: Int?
    let sizeDelta: Int64?
    let size: Int64?
    
    enum CodingKeys: String, CodingKey {
        case status
        case binary
        case oldPath = "old_path"
        case linesInserted = "lines_inserted"
        case linesDeleted = "lines_deleted"
        case sizeDelta = "size_delta"
        case size
    }
}

public struct PushCertificateInfo: Codable {
    let certificate: String
    let key: GpgKeyInfo
}

public struct GpgKeyInfo: Codable {
    let status: String
    let keyId: String
    let userId: String
    let fingerprint: String
    let userIds: [String]
    
    enum CodingKeys: String, CodingKey {
        case status
        case keyId = "key_id"
        case userId = "user_id"
        case fingerprint
        case userIds = "user_ids"
    }
}

public struct TrackingIdInfo: Codable {
    let system: String
    let id: String
}

public struct ProblemInfo: Codable {
    let message: String
    let status: String?
    let outcome: String?
}

public struct Requirement: Codable {
    let status: String
    let fallbackText: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case fallbackText = "fallback_text"
        case type
    }
}

public struct SubmitRequirementResultInfo: Codable, Identifiable {
    public let id = UUID()
    let name: String
    let description: String?
    let status: SubmitRequirementResultStatus
    let isLegacy: Bool
    let applicabilityExpressionResult: SubmitRequirementExpressionInfo?
    let submittabilityExpressionResult: SubmitRequirementExpressionInfo
    let overrideExpressionResult: SubmitRequirementExpressionInfo?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case status
        case isLegacy = "is_legacy"
        case applicabilityExpressionResult = "applicability_expression_result"
        case submittabilityExpressionResult = "submittability_expression_result"
        case overrideExpressionResult = "override_expression_result"
    }
}


public enum SubmitRequirementResultStatus: String, Codable {
    case satisfied = "SATISFIED"
    case unsatisfied = "UNSATISFIED"
    case overridden = "OVERRIDDEN"
    case notApplicable = "NOT_APPLICABLE"
    case error = "ERROR"
    case forced = "FORCED"
}

public struct SubmitRequirementExpressionInfo: Codable {
    let expression: String?
    let fulfilled: Bool
    let status: String
    //let passingAtoms: [String]?
    //let failingAtoms: [String]?
    //let atomExplanations: [String]?
    let errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case expression
        case fulfilled
        case status
        //case passingAtoms = "passing_atoms"
        //case failingAtoms = "failing_atoms"
        //case atomExplanations = "atom_explanations"
        case errorMessage = "error_message"
    }
}

public struct SubmitRecord: Codable {
    let status: SubmitRecordStatus
    let ok: [String: LabelInfo]?
    let reject: [String: LabelInfo]?
    let need: [String: LabelInfo]?
    let may: [String: LabelInfo]?
    let impossible: [String: LabelInfo]?
    let errorMessage: String?
    let ruleName: String?
    let labels: [Label]?
    let requirements: [Requirement]?
    
    enum CodingKeys: String, CodingKey {
        case status
        case ok = "OK"
        case reject = "REJECT"
        case need = "NEED"
        case may = "MAY"
        case impossible = "IMPOSSIBLE"
        case errorMessage = "error_message"
        case ruleName = "rule_name"
        case labels
        case requirements
    }
}

public enum SubmitRecordStatus: String, Codable {
    case ok = "OK"
    case notReady = "NOT_READY"
    case closedStatus = "CLOSED"
    case ruleError = "RULE_ERROR"
    case forced = "FORCED"
}

public struct Label: Codable {
    let label: String
    let status: LabelStatus
    let appliedBy: AccountInfo?
    
    enum CodingKeys: String, CodingKey {
        case label
        case status
        case appliedBy = "applied_by"
    }
}

public enum LabelStatus: String, Codable {
    case ok = "OK"
    case reject = "REJECT"
    case need = "NEED"
    case may = "MAY"
    case impossible = "IMPOSSIBLE"
}

public func decodeGerritChangeListResponse(from jsonString: String) throws -> [GerritChange] {
    // To prevent against Cross Site Script Inclusion (XSSI) attacks, the JSON
    // response body starts with a magic prefix line that must be stripped before
    // feeding the rest of the response body to a JSON parser:
    let cleanedJsonString = jsonString.replacingOccurrences(of: ")]}'\n", with: "")
    
    guard let jsonData = cleanedJsonString.data(using: .utf8) else {
        return []
    }
    
    let decoder = JSONDecoder()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    
    let changes = try decoder.decode([GerritChange].self, from: jsonData)
    return changes
}

extension String {
    func toDetectedAttributedString() -> AttributedString {
        var attributedString = AttributedString(self)

        let types = NSTextCheckingResult.CheckingType.link.rawValue

        guard let detector = try? NSDataDetector(types: types) else {
            return attributedString
        }

        let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: count))

        for match in matches {
            let range = match.range
            let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: range.lowerBound)
            let endIndex = attributedString.index(startIndex, offsetByCharacters: range.length)
            if match.resultType == .link, let url = match.url {
                attributedString[startIndex..<endIndex].link = url
            }
        }
        return attributedString
    }
}

public func decodeGerritSingleChangeResponse(from jsonString: String) throws -> GerritChange? {
    // To prevent against Cross Site Script Inclusion (XSSI) attacks, the JSON
    // response body starts with a magic prefix line that must be stripped before
    // feeding the rest of the response body to a JSON parser:
    let cleanedJsonString = jsonString.replacingOccurrences(of: ")]}'\n", with: "")
    
    guard let jsonData = cleanedJsonString.data(using: .utf8) else {
        return nil
    }
    
    let decoder = JSONDecoder()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
    decoder.dateDecodingStrategy = .formatted(dateFormatter)

    var change = try decoder.decode(GerritChange.self, from: jsonData)

    if change.messages != nil {
        for message in change.messages!.indices {
            change.messages![message].attributedMessage = change.messages![message].message.toDetectedAttributedString()
        }
    }

    return change
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
