public protocol ActionHandling {
    associatedtype Action
    
    /// Handle the given `Action`
    func handle(action: Action)
}

public struct StoreActionHandler<Key: Hashable, Action, Dependency> {
    private let handler: (inout CacheStore<Key>, Action, Dependency) -> Void
    
    public init(
        _ handler: @escaping (inout CacheStore<Key>, Action, Dependency) -> Void
    ) {
        self.handler = handler
    }
    
    public static var none: StoreActionHandler<Key, Action, Dependency> {
        StoreActionHandler { _, _, _ in }
    }
    
    public func handle(store: inout CacheStore<Key>, action: Action, dependency: Dependency) {
        handler(&store, action, dependency)
    }
}
