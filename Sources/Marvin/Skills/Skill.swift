
/// Interface for skills provided by the bot
public protocol Skill {

    func canProcess(_ messageInformation: Marvin.MessageInformation) -> Bool
    func process(_ messageInformation: Marvin.MessageInformation, response: @escaping (String) -> Void)
}
