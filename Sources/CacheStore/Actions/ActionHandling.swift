import Foundation

public protocol ActionHandling {
    associatedtype Action
    
    /// Handle the given `Action`
    func handle(action: Action)
}

public struct ActionEffect<Action> {
    public let id: AnyHashable
    public let effect: () async -> Action?
    
    public static var none: Self {
        ActionEffect { nil }
    }
    
    public init(
        id: AnyHashable = UUID(),
        effect: @escaping () async -> Action?
    ) {
        self.id = id
        self.effect = effect
    }
    
    public init(_ action: Action) {
        self.id = UUID()
        self.effect = { action }
    }
}

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
