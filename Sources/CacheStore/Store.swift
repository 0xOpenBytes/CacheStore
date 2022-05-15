import c
import Combine
import SwiftUI

// MARK: -

public class Store<Key: Hashable, Action, XYZ>: ObservableObject, ActionHandling {
    private var lock: NSLock
    var store: CacheStore<Key>
    private var actionHandler: StateActionHandling<Key, Action, XYZ>
    private let xyz: XYZ
    
    /// A publisher for the private `cache` that is mapped to a CacheStore
    var publisher: AnyPublisher<CacheStore<Key>, Never> {
        store.publisher
    }
    
    public required init(
        initialValues: [Key: Any],
        actionHandler: @escaping StateActionHandling<Key, Action, XYZ>,
        xyz: XYZ
    ) {
        lock = NSLock()
        store = CacheStore(initialValues: initialValues)
        self.actionHandler = actionHandler
        self.xyz = xyz
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
        actionHandler(&store, action, xyz)
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
    public func scope<ScopedKey: Hashable, ScopedAction, ScopedXYZ>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionTransformation: @escaping c.UniDirectionalTransformation<ScopedAction?, Action?>,
        xyzTransformation: c.UniDirectionalTransformation<XYZ, ScopedXYZ>,
        actionHandler: StateActionHandling<ScopedKey, ScopedAction, ScopedXYZ>? = nil,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> Store<ScopedKey, ScopedAction, ScopedXYZ> {
        let scopedStore = ScopedStore<Key, ScopedKey, Action, ScopedAction, XYZ, ScopedXYZ> (
            initialValues: [:],
            actionHandler: { _, _, _ in },
            xyz: xyzTransformation(xyz)
        )
        
        let scopedCacheStore = store.scope(
            keyTransformation: keyTransformation,
            defaultCache: defaultCache
        )
        
        scopedStore.store = scopedCacheStore
        scopedStore.parentStore = self
        scopedStore.actionHandler = { (store: inout CacheStore<ScopedKey>, action: ScopedAction, xyz: ScopedXYZ) in
            actionHandler?(&store, action, xyz)
            
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
