import Vapor


/// Message send via socket connection
struct SlackOutgoingMessage: Content {

    let id: UInt32 = 1// UInt32.random(in: 0..<UInt32.max)
    let channel: String
    let text: String
    let type: String = "message"

    init(to channel: String, text: String) {
        self.channel = channel
        self.text = text
    }
}
