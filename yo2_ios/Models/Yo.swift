import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct Yo: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUserId: String
    var toUserId: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "fromUserId"
        case toUserId = "toUserId"
        case createdAt = "createdAt"
    }

    init(id: String? = nil, fromUserId: String, toUserId: String, createdAt: Date = Date()) {
        self.id = id
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.createdAt = createdAt
    }
}
