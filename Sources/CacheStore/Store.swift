import c
import Combine
import SwiftUI

// MARK: -

public class Store<Key: Hashable, Action, XYZ>: ObservableObject, ActionHandling {
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
        store = CacheStore(initialValues: initialValues)
        self.actionHandler = actionHandler
        self.xyz = xyz
    }
    
    public func get<Value>(_ key: Key, as: Value.Type) -> Value? {
        store.get(key)
    }
    
    public func resolve<Value>(_ key: Key, as: Value.Type) -> Value {
        store.resolve(key)
    }
    
    public func handle(action: Action) {
        objectWillChange.send()
        actionHandler(&store, action, xyz)
    }
    
    /// Checks if the given `key` has a value or not
    func contains(_ key: Key) -> Bool {
        store.contains(key)
    }
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    func valuesInCache<Value>(
        ofType type: Value.Type = Value.self
    ) -> [Key: Value] {
        store.valuesInCache(ofType: type)
    }
    
    /// Creates a `ScopedStore`
    func scope<ScopedKey: Hashable, ScopedAction, ScopedXYZ>(
        keyTransformation: c.UniDirectionalTransformation<Key?, ScopedKey?>,
        actionTransformation: @escaping c.UniDirectionalTransformation<ScopedAction?, Action?>,
        xyzTransformation: c.UniDirectionalTransformation<XYZ, ScopedXYZ>,
        actionHandler: StateActionHandling<ScopedKey, ScopedAction, ScopedXYZ>? = nil,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> ScopedStore<Key, ScopedKey, Action, ScopedAction, XYZ, ScopedXYZ> {
        let scopedStore = ScopedStore<Key, ScopedKey, Action, ScopedAction, XYZ, ScopedXYZ> (
            initialValues: [:],
            actionHandler: { _, _, _ in },
            xyz: xyzTransformation(xyz)
        )
        
        scopedStore.store.cache = defaultCache
        scopedStore.parentStore = self
        scopedStore.actionHandler = { (store: inout CacheStore<ScopedKey>, action: ScopedAction, xyz: ScopedXYZ) in
            actionHandler?(&store, action, xyz)
            
            if let parentAction = actionTransformation(action) {
                scopedStore.parentStore?.handle(action: parentAction)
            }
        }
        
        store.cache.forEach { key, value in
            guard let scopedKey = keyTransformation(key) else { return }
            
            scopedStore.store.cache[scopedKey] = value
        }
        
        return scopedStore
    }
    
    /// Creates a `Binding` for the given `Key`
    func binding<Value>(
        _ key: Key,
        as: Value.Type = Value.self
    ) -> Binding<Value> {
        store.binding(key)
    }
    
    /// Creates a `Binding` for the given `Key` where the value is Optional
    func optionalBinding<Value>(
        _ key: Key,
        as: Value.Type = Value.self
    ) -> Binding<Value?> {
        store.optionalBinding(key)
    }
}
