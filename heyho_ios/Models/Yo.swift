import Foundation
import FirebaseFirestore

struct Yo: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUserId: String
    var toUserId: String
    var messageType: String // "hey" or "ho"
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "fromUserId"
        case toUserId = "toUserId"
        case messageType = "messageType"
        case createdAt = "createdAt"
    }

    init(id: String? = nil, fromUserId: String, toUserId: String, messageType: String = "hey", createdAt: Date = Date()) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.messageType = messageType
        self.createdAt = createdAt
    }
}
