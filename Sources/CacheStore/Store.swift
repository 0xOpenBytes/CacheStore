import c
import Combine
import SwiftUI

// MARK: -

public class Store<Key: Hashable, Action, Dependency>: ObservableObject, ActionHandling {
    private var lock: NSLock
    var store: CacheStore<Key>
    private var actionHandler: StateActionHandling<Key, Action, Dependency>
    private let dependency: Dependency
    
    /// A publisher for the private `cache` that is mapped to a CacheStore
    var publisher: AnyPublisher<CacheStore<Key>, Never> {
        store.publisher
    }
    
    public required init(
        initialValues: [Key: Any],
        actionHandler: @escaping StateActionHandling<Key, Action, Dependency>,
        dependency: Dependency
    ) {
        lock = NSLock()
        store = CacheStore(initialValues: initialValues)
        self.actionHandler = actionHandler
        self.dependency = dependency
    }
    
    public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
        store.get(key)
    }
    
    public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) -> Value {
        store.resolve(key)
    }
    
    public func handle(action: Action) {
        lock.lock()
        objectWillChange.send()
        actionHandler(&store, action, dependency)
        lock.unlock()
    }
    
    /// Checks if the given `key` has a value or not
    public func contains(_ key: Key) -> Bool {
        store.contains(key)
    }
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    public func valuesInCache<Value>(
        ofType type: Value.Type = Value.self
    ) -> [Key: Value] {
        store.valuesInCache(ofType: type)
    }
    
    /// Creates a `ScopedStore`
    public func scope<ScopedKey: Hashable, ScopedAction, ScopedDependency>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionHandler: @escaping StateActionHandling<ScopedKey, ScopedAction, ScopedDependency>,
        dependencyTransformation: (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil }
    ) -> Store<ScopedKey, ScopedAction, ScopedDependency> {
        let scopedStore = ScopedStore<Key, ScopedKey, Action, ScopedAction, Dependency, ScopedDependency> (
            initialValues: [:],
            actionHandler: { _, _, _ in },
            dependency: dependencyTransformation(dependency)
        )
        
        let scopedCacheStore = store.scope(
            keyTransformation: keyTransformation,
            defaultCache: defaultCache
        )
        
        scopedStore.store = scopedCacheStore
        scopedStore.parentStore = self
        scopedStore.actionHandler = { (store: inout CacheStore<ScopedKey>, action: ScopedAction, dependency: ScopedDependency) in
            actionHandler(&store, action, dependency)
            
            if let parentAction = actionTransformation(action) {
                scopedStore.parentStore?.handle(action: parentAction)
            }
        }
        
        store.cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedStore.store.cache[scopedKey] = value
        }
        
        return scopedStore
    }
    
    /// Creates a `ScopedStore`
    public func actionlessScope<ScopedKey: Hashable, ScopedDependency>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        dependencyTransformation: (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> Store<ScopedKey, Void, ScopedDependency> {
        scope(
            keyTransformation: keyTransformation,
            actionHandler: { _, _, _ in },
            dependencyTransformation: dependencyTransformation,
            defaultCache: defaultCache,
            actionTransformation: { _ in nil }
        )
    }
    
    /// Creates a `Binding` for the given `Key`
    public func binding<Value>(
        _ key: Key,
        as: Value.Type = Value.self
    ) -> Binding<Value> {
        store.binding(key)
    }
    
    /// Creates a `Binding` for the given `Key` where the value is Optional
    public func optionalBinding<Value>(
        _ key: Key,
        as: Value.Type = Value.self
    ) -> Binding<Value?> {
        store.optionalBinding(key)
    }
}

// MARK: - Void Dependency

public extension Store {
    /// Creates a `ScopedStore`
    func scope<ScopedKey: Hashable, ScopedAction>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionHandler: @escaping StateActionHandling<ScopedKey, ScopedAction, Void>,
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
