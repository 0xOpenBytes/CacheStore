import c

public typealias BiDirectionalTransformation = c.BiDirectionalTransformation

class ScopedCacheStore<Key: Hashable, ScopedKey: Hashable>: CacheStore<ScopedKey> {
    weak var parentCacheStore: CacheStore<Key>?
    private var keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>
    
    init(
        keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>
    ) {
        self.keyTransformation = keyTransformation
        
        super.init(initialValues: [:])
    }
    
    required init(initialValues: [ScopedKey: Any]) { fatalError("Not implemented") }
    
    override func set<Value>(value: Value, forKey key: ScopedKey) {
        super.set(value: value, forKey: key)
        
        guard let parentKey = keyTransformation.to(key) else { return }
        
        parentCacheStore?.set(value: value, forKey: parentKey)
    }
    
    override func copy() -> ScopedCacheStore<Key, ScopedKey> {
        let scopedCacheStore = ScopedCacheStore<Key, ScopedKey>(keyTransformation: keyTransformation)
        
        scopedCacheStore.cache = cache
        scopedCacheStore.parentCacheStore = parentCacheStore
        
        return scopedCacheStore
    }
}
