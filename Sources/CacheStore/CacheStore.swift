import c
import SwiftUI

public class CacheStore<CacheKey: Hashable>: ObservableObject, Cacheable {
    private var lock: NSLock
    @Published private var cache: [CacheKey: Any]
    
    required public init(initialValues: [CacheKey: Any]) {
        lock = NSLock()
        cache = initialValues
    }
    
    public func get<Value>(_ key: CacheKey) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key] as? Value
    }
    
    public func resolve<Value>(_ key: CacheKey) -> Value { get(key)! }
    
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
    func scope<ScopedCacheKey: Hashable>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedCacheKey?>
    ) -> ScopedCacheStore<Key, ScopedCacheKey> {
        let scopedCacheStore = ScopedCacheStore(keyTransformation: keyTransformation)
        scopedCacheStore.parentCacheStore = self
        return scopedCacheStore
    }
}
