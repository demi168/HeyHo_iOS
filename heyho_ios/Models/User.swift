import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var displayName: String
    var createdAt: Date
    var fcmToken: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "displayName"
        case createdAt = "createdAt"
        case fcmToken = "fcmToken"
    }

    init(id: String? = nil, displayName: String, createdAt: Date = Date(), fcmToken: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.fcmToken = fcmToken
    }
}
