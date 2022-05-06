import c
import SwiftUI

public class CacheStore<CacheKey: Hashable>: ObservableObject, Cacheable {
    private var lock: NSLock
    @Published private var cache: [CacheKey: Any]
    
    required public init(initialValues: [CacheKey: Any]) {
        lock = NSLock()
        cache = initialValues
    }
    
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

public class ScopedCacheStore<CacheKey: Hashable, ScopedCacheKey: Hashable>: CacheStore<ScopedCacheKey> {
    weak var parentCacheStore: CacheStore<CacheKey>?
    private var keyTransformation: c.BiDirectionalTransformation<CacheKey?, ScopedCacheKey?>?
    
    init(
        keyTransformation: c.BiDirectionalTransformation<CacheKey?, ScopedCacheKey?>
    ) {
        self.keyTransformation = keyTransformation
        
        super.init(initialValues: [:])
    }
    
    required public init(initialValues: [ScopedCacheKey: Any]) {
        super.init(initialValues: initialValues)
    }
    
    override public func set<Value>(value: Value, forKey key: ScopedCacheKey) {
        super.set(value: value, forKey: key)
        
        guard
            let keyTransformation = keyTransformation,
            let parentKey = keyTransformation.to(key)
        else { return }

        parentCacheStore?.set(value: value, forKey: parentKey)
    }
}

public extension CacheStore {
    func contains(_ key: CacheKey) -> Bool {
        cache[key] != nil
    }
    
    func scope<ScopedCacheKey: Hashable>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedCacheKey?>
    ) -> ScopedCacheStore<Key, ScopedCacheKey> {
        let scopedCacheStore = ScopedCacheStore(keyTransformation: keyTransformation)
        
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
}
