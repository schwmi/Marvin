import Vapor


/// Bot which handles send/receive connection with slack
public final class Marvin {

    public struct MessageInformation {
        let isDirectMessage: Bool
        let sender: String?
        let text: String
    }

    private let app: Application
    private let slackToken: String

    // MARK: - Properties

    let skills: [Skill]

    // MARK: - Lifecycle

    /// Initializes the bot
    ///
    /// - Parameters:
    ///   - skills: Array of skills provided by the bot -> first matching skill in the array executed
    ///   - environment: the environment in which the application is running
    /// - Throws: tbd
    public init(skills: [Skill], environment: Environment) throws {
        self.app = try Application(config: Config.default(), environment: environment, services: Services.default())
        guard let slackToken = Environment.slackToken else {
            fatalError("Missing Slack Token - Cannot establish websocket connection")
        }
        self.slackToken = slackToken
        self.skills = skills
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

    func sendMessage(_ message: SlackOutgoingMessage) throws {
        let headers = HTTPHeaders([("Content-Type", "application/json"), ("Authorization", "Bearer \(self.slackToken)")])
        _ = try app.client().post("https://slack.com/api/chat.postMessage",
                               headers: headers) { post in
                                try post.content.encode(message)
        }
    }

    func establishRTMConnection(connectionRequestResponse: SlackRTMConnectionResponse) throws {
        _ = try app.client().webSocket(connectionRequestResponse.url).flatMap { ws -> Future<Void> in
            ws.onText({ ws, message in
                guard let msgData = message.data(using: .utf8) else { return }
                guard let incomingMessage = try? JSONDecoder().decode(SlackIncomingMessage.self, from: msgData) else { return }

                switch incomingMessage {
                case .message(let message):
                    // TODO: Find out if direct and sender name
                    let messageInformation = MessageInformation(isDirectMessage: false, sender: nil, text: message.text)
                    for skill in self.skills {
                        guard skill.canProcess(messageInformation) else { continue }

                        skill.process(messageInformation, response: { response in
                            let message = SlackOutgoingMessage(channel: message.channel,
                                                               text: response,
                                                               username: connectionRequestResponse.bot.name)
                            try? self.sendMessage(message)
                        })
                    }

                default:
                    print("Ignore Message type \(incomingMessage)")
                }
            })

            return ws.onClose
        }
    }
}


private extension Environment {

    static var slackToken: String? { return self.get("SLACK_TOKEN") }
}
