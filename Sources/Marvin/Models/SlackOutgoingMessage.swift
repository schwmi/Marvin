import Vapor


/// Message send via socket connection
struct SlackOutgoingMessage: Content {

    let id: UInt32 = UInt32.random(in: 0..<UInt32.max)
    let channel: String
    let text: String
    let username: String
    let type: String = "message"
    let asUser: Bool = false
    let iconEmoji: String = ":robot_face:"


    init(channel: String, text: String, username: String) {
        self.channel = channel
        self.text = text
        self.username = username
    }

    enum CodingKeys: String, CodingKey {
        case id, channel, text, username, type
        case asUser = "as_user"
        case iconEmoji = "icon_emoji"
    }
}
