

/// Collection of some basic bot skills provided by the bot
public enum BasicSkills {

    public struct Greet: Skill {

        public init() {}

        public func canProcess(_ messageInformation: Marvin.MessageInformation) -> Bool {
            return true
        }

        public func process(_ messageInformation: Marvin.MessageInformation, response: @escaping (String) -> Void) {
            if let sender = messageInformation.sender {
                response("Hi \(sender)!")
            } else {
                response("Hi!")
            }
        }
    }
}
