import Vapor


/// Response when establishing a connection
struct SlackUserInfo: Content {

    struct User: Content {
        let name: String
    }

    let user: User
}
