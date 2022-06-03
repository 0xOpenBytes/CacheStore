import Foundation

/// ActionHandlers can handle any value of `Action`. Normally `Action` is an enum.
public protocol ActionHandling {
    /// `Action` Type that is passed into the handle function
    associatedtype Action
    
    /// Handle the given `Action`
    func handle(action: Action)
}

/// Async effect produced from an `Action` that can optionally produce another `Action`
public struct ActionEffect<Action> {
    /// ID used to identify and cancel the effect
    public let id: AnyHashable
    /// Async closure that optionally produces an `Action`
    public let effect: () async -> Action?
    
    /// No effect
    public static var none: Self {
        ActionEffect { nil }
    }
    
    /// init for `ActionEffect<Action>` taking an async effect
    public init(
        id: AnyHashable = UUID(),
        effect: @escaping () async -> Action?
    ) {
        self.id = id
        self.effect = effect
    }
    
    /// init for `ActionEffect<Action>` taking an immediate action
    public init(_ action: Action) {
        self.id = UUID()
        self.effect = { action }
    }
}

/// Handles an `Action` that modifies a `CacheStore` using a `Dependency`
public struct StoreActionHandler<Key: Hashable, Action, Dependency> {
    private let handler: (inout CacheStore<Key>, Action, Dependency) -> ActionEffect<Action>?
    
    /// init for `StoreActionHandler<Key: Hashable, Action, Dependency>`
    public init(
        _ handler: @escaping (inout CacheStore<Key>, Action, Dependency) -> ActionEffect<Action>?
    ) {
        self.handler = handler
    }
    
    /// `StoreActionHandler` that doesn't handle any `Action`
    public static var none: StoreActionHandler<Key, Action, Dependency> {
        StoreActionHandler { _, _, _ in nil }
    }
    
    /// Mutate `CacheStore<Key>` for `Action` with `Dependency`
    public func handle(
        store: inout CacheStore<Key>,
        action: Action,
        dependency: Dependency
    ) -> ActionEffect<Action>? {
        handler(&store, action, dependency)
    }
}
