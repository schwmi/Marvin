import Vapor


public final class Marvin {

    private let app: Application
    private let slackToken: String

    // MARK: - Lifecylce

    public init(_ env: Environment) throws {
        self.app = try Application(config: Config.default(), environment: env, services: Services.default())
        guard let slackToken = Environment.slackToken else {
            fatalError("Missing Slack Token - Cannot establish websocket connection")
        }
        self.slackToken = slackToken
    }

    public func run() throws {
        let connectionRequestResponse = try self.executeRTMConnectionRequest(token: self.slackToken)
        try self.establishRTMConnection(connectionRequestResponse: connectionRequestResponse)

        try self.app.run()
    }
}

// MARK: - Private

private extension Marvin {

    func executeRTMConnectionRequest(token: String) throws -> SlackRTMConnectionResponse {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
        return try app.client().get("https://slack.com/api/rtm.connect",
                                            headers: headers) { get in
                                                try get.query.encode(["token": token])
            }.flatMap { try $0.content.decode(SlackRTMConnectionResponse.self) }.wait()
    }

    func sendMessage(_ message: SlackOutgoingMessage) {
        let headers = HTTPHeaders([("Content-Type", "application/json"), ("Authorization", "Bearer \(self.slackToken)")])
        try? app.client().post("https://slack.com/api/chat.postMessage",
                               headers: headers) { post in
                                try post.content.encode(message)
        }
    }

    func establishRTMConnection(connectionRequestResponse: SlackRTMConnectionResponse) throws {
        try app.client().webSocket(connectionRequestResponse.url).flatMap { ws -> Future<Void> in
            ws.onText({ ws, message in
                guard let msgData = message.data(using: .utf8) else { return }
                guard let incomingMessage = try? JSONDecoder().decode(SlackIncomingMessage.self, from: msgData) else { return }

                switch incomingMessage {
                case .message(let message):

                    let message = SlackOutgoingMessage(channel: message.channel, text: "Hello", username: connectionRequestResponse.bot.name)
                    self.sendMessage(message)

                default:
                    print("Ignore")
                }
            })

            return ws.onClose
        }
    }
}


private extension Environment {

    static var slackToken: String? { return self.get("SLACK_TOKEN") }
}
