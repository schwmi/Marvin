import Vapor


/// Slack Messages received on socket
enum SlackIncomingMessage: Decodable {

    enum Error: Swift.Error {
        case unknownMessageType
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    struct UserTyping: Decodable {
        let channel: String
        let user: String
    }

    struct Message: Decodable {
        let user: String
        let text: String
        let client_msg_id: String
        let team: String
        let channel: String
        let event_ts: String
        let ts: String
    }

    case hello
    case userTyping(UserTyping)
    case message(Message)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "hello":
            self = .hello
        case "user_typing":
            self = try .userTyping(.init(from: decoder))
        case "message":
            self = try .message(.init(from: decoder))
        default:
            throw Error.unknownMessageType
        }
    }
}
