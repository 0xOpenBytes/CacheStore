import c
import Combine
import SwiftUI

public class CacheStore<CacheKey: Hashable>: ObservableObject, Cacheable  {
     
    // MARK: - Properties
    
    private var lock: NSLock
    @Published private var cache: [CacheKey: Any]
    
    // MARK: - InitializationCacheable
    
    required public init(initialValues: [CacheKey: Any]) {
        lock = NSLock()
        cache = initialValues
    }
    
    // MARK: - Cacheable
    
    public func get<Value>(_ key: CacheKey, as: Value.Type = Value.self) -> Value? {
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
    
    public func resolve<Value>(_ key: CacheKey, as: Value.Type = Value.self) -> Value { get(key)! }
    
    public func set<Value>(value: Value, forKey key: CacheKey) {
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
    
    public func remove(_ key: CacheKey) {
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
    var publisher: AnyPublisher<CacheStore, Never> {
        $cache.map(CacheStore.init).eraseToAnyPublisher()
    }
    
    func contains(_ key: CacheKey) -> Bool {
        cache[key] != nil
    }
    
    func scope<ScopedCacheKey: Hashable>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedCacheKey?>,
        defaultCache: [ScopedCacheKey: Any] = [:]
    ) -> ScopedCacheStore<Key, ScopedCacheKey> {
        let scopedCacheStore = ScopedCacheStore(keyTransformation: keyTransformation)
        
        scopedCacheStore.cache = defaultCache
        scopedCacheStore.parentCacheStore = self
        
        cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedCacheStore.cache[scopedKey] = value
        }
        
        return scopedCacheStore
    }
    
    func binding<Value>(
        _ key: CacheKey,
        as: Value.Type = Value.self
    ) -> Binding<Value> {
        Binding(
            get: { self.resolve(key) },
            set: { self.set(value: $0, forKey: key) }
        )
    }
    
    func optionalBinding<Value>(
        _ key: CacheKey,
        as: Value.Type = Value.self
    ) -> Binding<Value?> {
        Binding(
            get: { self.get(key) },
            set: { self.set(value: $0, forKey: key) }
        )
    }
}
