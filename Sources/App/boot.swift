import Vapor

/// Called after your application has initialized.
public func boot(_ app: Application) throws {
    guard let slackToken = Environment.get("SLACK_TOKEN") else {
        fatalError("Missing Slack Token - Cannot establish websocket connection")
    }

    let headers = HTTPHeaders([("Content-Type", "application/x-www-form-urlencoded")])
    let response = try app.client().get("https://slack.com/api/rtm.connect",
                                                  headers: headers) { get in
                                                    try get.query.encode(["token": slackToken])
        }.flatMap { try $0.content.decode(SlackRTMConnectionResponse.self) }.wait()

    let rtmConnection = try app.client().webSocket(response.url).flatMap { ws -> Future<Void> in
        ws.onText({ ws, message in
            guard let msgData = message.data(using: .utf8) else { return }
            guard let incomingMessage = try? JSONDecoder().decode(SlackIncomingMessage.self, from: msgData) else { return }

            switch incomingMessage {
            case .message(let message):

                let message = SlackOutgoingMessage(channel: message.channel, text: "Hello", username: response.bot.name)

                let headers = HTTPHeaders([("Content-Type", "application/json"), ("Authorization", "Bearer \(slackToken)")])
                let response = try? app.client().post("https://slack.com/api/chat.postMessage",
                                      headers: headers) { post in
                                        try post.content.encode(message)
                    }
                response?.map({ (response) -> () in
                    print(response)
                })

            default:
                print("Ignore")
            }
        })

        return ws.onClose
    }

    try rtmConnection.wait()
}


