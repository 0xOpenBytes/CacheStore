import c
import Combine
import SwiftUI

// MARK: -

public class Store<Key: Hashable, Action, Dependency>: ObservableObject, ActionHandling {
    private var lock: NSLock
    private var store: CacheStore<Key>
    private var actionHandler: StoreActionHandler<Key, Action, Dependency>
    private let dependency: Dependency
    
    @Published var xyz: CacheStore<Key>
    
    /// A publisher for the private `cache` that is mapped to a CacheStore
    public var publisher: AnyPublisher<CacheStore<Key>, Never> {
        xyz.publisher
    }
    
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency
    ) {
        lock = NSLock()
        store = CacheStore(initialValues: initialValues)
        xyz = store
        self.actionHandler = actionHandler
        self.dependency = dependency
    }
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
        xyz.get(key)
    }
    
    /// Resolve the value in the `cache` using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value is always in the `cache`.
    public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) -> Value {
        xyz.resolve(key)
    }
    
    /// Checks to make sure the cache has the required keys, otherwise it will throw an error
    @discardableResult
    public func require(keys: Set<Key>) throws -> Self {
        try xyz.require(keys: keys)
        
        return self
    }
    
    /// Checks to make sure the cache has the required key, otherwise it will throw an error
    @discardableResult
    public func require(_ key: Key) throws -> Self {
        try xyz.require(keys: [key])
        
        return self
    }
    
    public func handle(action: Action) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.handle(action: action)
            }
            return
        }
        
        lock.lock()
//        objectWillChange.send()
        actionHandler.handle(store: &xyz, action: action, dependency: dependency)
        lock.unlock()
    }
    
    /// Checks if the given `key` has a value or not
    public func contains(_ key: Key) -> Bool {
        xyz.contains(key)
    }
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    public func valuesInCache<Value>(
        ofType type: Value.Type = Value.self
    ) -> [Key: Value] {
        xyz.valuesInCache(ofType: type)
    }
    
    /// Creates a `ScopedStore`
    public func scope<ScopedKey: Hashable, ScopedAction, ScopedDependency>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>,
        dependencyTransformation: (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil }
    ) -> Store<ScopedKey, ScopedAction, ScopedDependency> {
        let scopedStore = ScopedStore<Key, ScopedKey, Action, ScopedAction, Dependency, ScopedDependency> (
            initialValues: [:],
            actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>.none,
            dependency: dependencyTransformation(dependency)
        )
        
        let scopedCacheStore = xyz.scope(
            keyTransformation: keyTransformation,
            defaultCache: defaultCache
        )
        
        scopedStore.store = scopedCacheStore
        scopedStore.parentStore = self
        scopedStore.actionHandler = StoreActionHandler { (store: inout CacheStore<ScopedKey>, action: ScopedAction, dependency: ScopedDependency) in
            actionHandler.handle(store: &store, action: action, dependency: dependency)
            
            if let parentAction = actionTransformation(action) {
                scopedStore.parentStore?.handle(action: parentAction)
            }
        }
        
        xyz.cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedStore.xyz.cache[scopedKey] = value
        }
        
        return scopedStore
    }
    
    /// Creates an Actionless `ScopedStore`
    public func actionlessScope<ScopedKey: Hashable, ScopedDependency>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        dependencyTransformation: (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> Store<ScopedKey, Void, ScopedDependency> {
        scope(
            keyTransformation: keyTransformation,
            actionHandler: StoreActionHandler<ScopedKey, Void, ScopedDependency>.none,
            dependencyTransformation: dependencyTransformation,
            defaultCache: defaultCache,
            actionTransformation: { _ in nil }
        )
    }
    
    /// Creates a `Binding` for the given `Key` using an `Action` to set the value
    public func binding<Value>(
        _ key: Key,
        as: Value.Type = Value.self,
        using: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.resolve(key) },
            set: { self.handle(action: using($0)) }
        )
    }
    
    /// Creates a `Binding` for the given `Key`, where the value is Optional, using an `Action` to set the value
    public func optionalBinding<Value>(
        _ key: Key,
        as: Value.Type = Value.self,
        using: @escaping (Value?) -> Action
    ) -> Binding<Value?> {
        Binding(
            get: { self.get(key) },
            set: { self.handle(action: using($0)) }
        )
    }
}

// MARK: - Void Dependency

public extension Store {
    /// Creates a `ScopedStore`
    func scope<ScopedKey: Hashable, ScopedAction>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, Void>,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil }
    ) -> Store<ScopedKey, ScopedAction, Void> {
        scope(
            keyTransformation: keyTransformation,
            actionHandler: actionHandler,
            dependencyTransformation: { _ in () },
            defaultCache: defaultCache,
            actionTransformation: actionTransformation
        )
    }
    
    /// Creates a `ScopedStore`
    func actionlessScope<ScopedKey: Hashable>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> Store<ScopedKey, Void, Void> {
        actionlessScope(
            keyTransformation: keyTransformation,
            dependencyTransformation: { _ in () },
            defaultCache: defaultCache
        )
    }
}
