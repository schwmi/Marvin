import Vapor


/// Bot which handles send/receive connection with slack
public final class Marvin {

    public struct MessageInformation {
        public let isDirectMessage: Bool
        public let sender: String?
        public let text: String
    }

    private let app: Application
    private let slackToken: String
    private weak var websocket: WebSocket?

    // MARK: - Properties

    let skills: [Skill]

    // MARK: - Lifecycle

    /// Initializes the bot
    ///
    /// - Parameters:
    ///   - skills: Array of skills provided by the bot -> first matching skill in the array executed
    /// - Throws: tbd
    public init(skills: [Skill]) throws {
        var environment = try Environment.detect()
        try LoggingSystem.bootstrap(from: &environment)
        self.app = Application(environment)
        guard let slackToken = Environment.slackToken else {
            fatalError("Missing Slack Token - Cannot establish websocket connection")
        }

        self.slackToken = slackToken
        self.skills = skills
    }

    public func run() throws {
        try self.establishBotConnection()
        self.setupBotRestartRoute()

        defer { app.shutdown() }
        try self.app.run()
    }
}

// MARK: - Private

private extension Marvin {

    func setupBotRestartRoute() {
        self.app.post("restartBot") { [weak self] request -> HTTPStatus in
            guard let self = self else { return .internalServerError }

            do {
                try self.establishBotConnection()
                return .ok
            } catch {
                print("Error when creating connection \(error)")
                return .internalServerError
            }
        }
    }

    func establishBotConnection() throws {
        if let websocket = self.websocket, websocket.isClosed == false {
            _ = websocket.close()
        }
        self.executeRTMConnectionRequest().whenComplete { result in
            switch result {
            case .success(let connectionRequestResponse):
                try? self.establishRTMConnection(connectionRequestResponse: connectionRequestResponse)
            case .failure(let error):
                print("Error when trying to establish RTM connection \(error)")
            }
        }
    }

    func executeRTMConnectionRequest() -> EventLoopFuture<SlackRTMConnectionResponse> {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
        return self.app.client.get("https://slack.com/api/rtm.connect", headers: headers) { request in
            try request.query.encode(["token": self.slackToken])
        }.flatMapThrowing { response in
            return try response.content.decode(SlackRTMConnectionResponse.self)
        }
    }

    func sendMessage(_ message: SlackOutgoingMessage) throws {
        let headers = HTTPHeaders([("Content-Type", "application/json"), ("Authorization", "Bearer \(self.slackToken)")])

        _ = self.app.client.post("https://slack.com/api/chat.postMessage", headers: headers) { request in
            try request.content.encode(message)
        }
    }

    func retrieveConversationInfo(for channelID: String) throws -> EventLoopFuture<SlackConversationsInfo> {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])

        return self.app.client.get("https://slack.com/api/conversations.info", headers: headers) { request in
            try request.query.encode(["token": self.slackToken, "channel": channelID])
        }.flatMapThrowing { response in
            try response.content.decode(SlackConversationsInfo.self)
        }
    }

    func retrieveUserInfo(for userID: String) throws -> EventLoopFuture<SlackUserInfo> {
        let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
        return app.client.get("https://slack.com/api/users.info", headers: headers) { request in
            try request.query.encode(["token": self.slackToken, "user": userID])
        }.flatMapThrowing { response in
            try response.content.decode(SlackUserInfo.self)
        }
    }

    func establishRTMConnection(connectionRequestResponse: SlackRTMConnectionResponse) throws {
        let myInfo = connectionRequestResponse.bot

        _ = WebSocket.connect(to: connectionRequestResponse.url, on: self.app.eventLoopGroup.next()) { ws in
            print("Did start slack websocket connection")
            self.websocket = ws
            ws.onText({ ws, message in
                guard let msgData = message.data(using: .utf8) else { return }
                guard let incomingMessage = try? JSONDecoder().decode(SlackIncomingMessage.self, from: msgData) else { return }

                switch incomingMessage {
                case .message(let message):
                    guard let conversationInfo = try? self.retrieveConversationInfo(for: message.channel) else { return }
                    guard let userInfo = try? self.retrieveUserInfo(for: message.user) else { return }

                    conversationInfo.and(userInfo).whenSuccess { conversationInfo, userInfo in
                        let messageDirectedToMe = message.text.contains("@\(myInfo.id)")
                        guard conversationInfo.channel.isDirectMessage || messageDirectedToMe else { return }

                        print("Did receive message from \(userInfo.user.name)")
                        let messageInformation = MessageInformation(isDirectMessage: conversationInfo.channel.isDirectMessage, sender: userInfo.user.name, text: message.text)
                        self.respondToMessage(messageInformation, inChannel: message.channel, withName: myInfo.name)
                    }
                default:
                    print("Ignore Message type \(incomingMessage)")
                }
            })

            ws.onPong { ws in
                ws.sendPing()
            }

            ws.onClose.whenComplete { _ in
                print("Websocket did close")
            }
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
