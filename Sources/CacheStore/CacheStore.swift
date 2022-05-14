import c
import Combine
import SwiftUI

// MARK: -

public class CacheStore<Key: Hashable>: ObservableObject, Cacheable {
    private var lock: NSLock
    @Published private var cache: [Key: Any]
    
    required public init(initialValues: [Key: Any]) {
        lock = NSLock()
        cache = initialValues
    }

    public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let value = cache[key] as? Value else {
            return nil
        }
        
        let mirror = Mirror(reflecting: value)
        
        if mirror.displayStyle != .optional {
            return value
        }
        
        if mirror.children.isEmpty {
            return nil
        }
        
        guard let (_, unwrappedValue) = mirror.children.first else { return nil }
        
        guard let value = unwrappedValue as? Value else {
            return nil
        }
        
        return value
    }
    
    public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) -> Value { get(key)! }
    
    public func set<Value>(value: Value, forKey key: Key) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.set(value: value, forKey: key)
            }
            return
        }
        
        lock.lock()
        cache[key] = value
        lock.unlock()
    }
    
    public func remove(_ key: Key) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.remove(key)
            }
            return
        }
        
        lock.lock()
        cache[key] = nil
        lock.unlock()
    }
}

// MARK: -

public extension CacheStore {
    /// A publisher for the private `cache` that is mapped to a CacheStore
    var publisher: AnyPublisher<CacheStore, Never> {
        $cache.map(CacheStore.init).eraseToAnyPublisher()
    }
    
    /// Checks if the given `key` has a value or not
    func contains(_ key: Key) -> Bool {
        cache[key] != nil
    }
    
    /// Update the value of a key by mutating the value passed into the `updater` parameter
    func update<Value>(
        _ key: Key,
        as: Value.Type = Value.self,
        updater: (inout Value?) -> Void
    ) {
        var value: Value? = get(key)
        updater(&value)
        
        if let value = value {
            set(value: value, forKey: key)
        }
    }
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    func valuesInCache<Value>(
        ofType: Value.Type = Value.self
    ) -> [Key: Value] {
        cache.compactMapValues { $0 as? Value }
    }
    
    /// Creates a `ScopedCacheStore` with the given key transformation and default cache
    func scope<ScopedKey: Hashable>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> ScopedCacheStore<Key, ScopedKey> {
        let scopedCacheStore = ScopedCacheStore(keyTransformation: keyTransformation)
        
        scopedCacheStore.cache = defaultCache
        scopedCacheStore.parentCacheStore = self
        
        cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedCacheStore.cache[scopedKey] = value
        }
        
        return scopedCacheStore
    }
    
    /// Creates a `Binding` for the given `Key`
    func binding<Value>(
        _ key: Key,
        as: Value.Type = Value.self
    ) -> Binding<Value> {
        Binding(
            get: { self.resolve(key) },
            set: { self.set(value: $0, forKey: key) }
        )
    }
    
    /// Creates a `Binding` for the given `Key` where the value is Optional
    func optionalBinding<Value>(
        _ key: Key,
        as: Value.Type = Value.self
    ) -> Binding<Value?> {
        Binding(
            get: { self.get(key) },
            set: { self.set(value: $0, forKey: key) }
        )
    }
}
