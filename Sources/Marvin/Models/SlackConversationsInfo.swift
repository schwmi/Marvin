import Vapor


/// Response when establishing a connection
struct SlackConversationsInfo: Content {

    struct Channel: Content {
        let isDirectMessage: Bool


        enum CodingKeys: String, CodingKey {
            case isDirectMessage = "is_im"
        }
    }

    let channel: Channel
}
