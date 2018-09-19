import Vapor


public final class Marvin {

    private let app: Application

    // MARK: - Lifecylce

    public init(_ env: Environment) throws {
        self.app = try Application(config: Config.default(), environment: env, services: Services.default())
    }

    public func run() throws {
        try self.app.run()
    }
}
