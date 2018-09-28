import Vapor


/// Bot which handles send/receive connection with slack
public final class Marvin {

    public struct MessageInformation {
        public let isDirectMessage: Bool
        public let sender: String?
        public let text: String
    }

    private let app: Application
    private let router: Router
    private let slackToken: String
    private weak var websocket: WebSocket?

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
        let router = EngineRouter.default()
        self.router = router

        var services = Services.default()
        services.register(router, as: Router.self)
        self.app = try Application(config: Config.default(), environment: environment, services: services)
        guard let slackToken = Environment.slackToken else {
            fatalError("Missing Slack Token - Cannot establish websocket connection")
        }
        self.slackToken = slackToken
        self.skills = skills
    }

    public func run() throws {
        try self.establishBotConnection()
        self.setupBotRestartRoute()

        try self.app.run()
    }
}

// MARK: - Private

private extension Marvin {

    func setupBotRestartRoute() {
        self.router.post("restartBot") { [weak self] Request -> HTTPStatus in
            guard let `self` = self else { return .internalServerError }

            try self.establishBotConnection()
            return .ok
        }
    }

    func establishBotConnection() throws {
        if let websocket = self.websocket {
            websocket.close()
        }
        let connectionRequestResponse = try self.executeRTMConnectionRequest()
        try self.establishRTMConnection(connectionRequestResponse: connectionRequestResponse)
    }

    func executeRTMConnectionRequest() throws -> SlackRTMConnectionResponse {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
        return try app.client().get("https://slack.com/api/rtm.connect",
                                            headers: headers) { get in
                                                try get.query.encode(["token": self.slackToken])
            }.flatMap { try $0.content.decode(SlackRTMConnectionResponse.self) }.wait()
    }

    func sendMessage(_ message: SlackOutgoingMessage) throws {
        let headers = HTTPHeaders([("Content-Type", "application/json"), ("Authorization", "Bearer \(self.slackToken)")])
        _ = try app.client().post("https://slack.com/api/chat.postMessage",
                               headers: headers) { post in
                                try post.content.encode(message)
        }
    }

    func retrieveConversationInfo(for channelID: String) throws -> EventLoopFuture<SlackConversationsInfo> {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
        return try app.client().get("https://slack.com/api/conversations.info",
                                    headers: headers) { get in
                                        try get.query.encode(["token": self.slackToken, "channel": channelID])
            }.flatMap { try $0.content.decode(SlackConversationsInfo.self) }
    }

    func retrieveUserInfo(for userID: String) throws -> EventLoopFuture<SlackUserInfo> {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
        return try app.client().get("https://slack.com/api/users.info",
                                    headers: headers) { get in
                                        try get.query.encode(["token": self.slackToken, "user": userID])
            }.flatMap { try $0.content.decode(SlackUserInfo.self) }
    }

    func establishRTMConnection(connectionRequestResponse: SlackRTMConnectionResponse) throws {
        let myInfo = connectionRequestResponse.bot
        _ = try app.client().webSocket(connectionRequestResponse.url).flatMap { ws -> Future<Void> in
            self.websocket = ws
            ws.onText({ ws, message in
                guard let msgData = message.data(using: .utf8) else { return }
                guard let incomingMessage = try? JSONDecoder().decode(SlackIncomingMessage.self, from: msgData) else { return }

                switch incomingMessage {
                case .message(let message):
                    guard let conversationInfo = try? self.retrieveConversationInfo(for: message.channel) else { return }
                    guard let userInfo = try? self.retrieveUserInfo(for: message.user) else { return }

                    conversationInfo.and(userInfo).do { conversationInfo, userInfo in
                        let messageDirectedToMe = message.text.contains("@\(myInfo.id)")
                        guard conversationInfo.channel.isDirectMessage || messageDirectedToMe else { return }

                        let messageInformation = MessageInformation(isDirectMessage: conversationInfo.channel.isDirectMessage, sender: userInfo.user.name, text: message.text)
                        self.respondToMessage(messageInformation, inChannel: message.channel, withName: myInfo.name)
                        }.catch({ error in
                            print("Error fetch converation and user info \(error)")
                        })

                default:
                    print("Ignore Message type \(incomingMessage)")
                }
            })

            return ws.onClose
        }
    }

    func respondToMessage(_ message: MessageInformation, inChannel channel: String, withName name: String) {
        for skill in self.skills {
            guard skill.canProcess(message) else { continue }

            skill.process(message, response: { response in
                let message = SlackOutgoingMessage(channel: channel,
                                                   text: response,
                                                   username: name)
                try? self.sendMessage(message)
            })
            return
        }
    }
}


private extension Environment {

    static var slackToken: String? { return self.get("SLACK_TOKEN") }
}
