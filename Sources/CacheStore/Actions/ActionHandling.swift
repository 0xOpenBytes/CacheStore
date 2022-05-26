public protocol ActionHandling {
    associatedtype Action
    
    /// Handle the given `Action`
    func handle(action: Action)
}

public typealias ActionEffect<Action> = () async -> Action?

public struct StoreActionHandler<Key: Hashable, Action, Dependency> {
    private let handler: (inout CacheStore<Key>, Action, Dependency) -> ActionEffect<Action>?
    
    public init(
        _ handler: @escaping (inout CacheStore<Key>, Action, Dependency) -> ActionEffect<Action>?
    ) {
        self.handler = handler
    }
    
    public static var none: StoreActionHandler<Key, Action, Dependency> {
        StoreActionHandler { _, _, _ in nil }
    }
    
    public func handle(
        store: inout CacheStore<Key>,
        action: Action,
        dependency: Dependency
    ) -> ActionEffect<Action>? {
        handler(&store, action, dependency)
    }
}
