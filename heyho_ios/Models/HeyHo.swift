import Foundation
import FirebaseFirestore

enum MessageType: String, Codable {
    case hey = "hey"
    case ho = "ho"
    case letsGo = "letsGo"
}

struct HeyHo: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUserId: String
    var toUserId: String
    var messageType: MessageType
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "fromUserId"
        case toUserId = "toUserId"
        case messageType = "messageType"
        case createdAt = "createdAt"
    }

    init(id: String? = nil, fromUserId: String, toUserId: String, messageType: MessageType = .hey, createdAt: Date? = nil) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.messageType = messageType
        self.createdAt = createdAt
    }
}
