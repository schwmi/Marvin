import Vapor


/// Response when establishing a connection
struct SlackRTMConnectionResponse: Content {

    struct Team: Content {
        let id: String
        let name: String
        let domain: String
    }

    struct Bot: Content {
        let id: String
        let name: String
    }

    let url: String
    let ok: Bool
    let team: Team
    let bot: Bot

    enum CodingKeys: String, CodingKey {
        case url
        case ok
        case team
        case bot = "self"
    }
}
