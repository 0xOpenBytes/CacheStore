import c

class ScopedCacheStore<Key: Hashable, ScopedKey: Hashable>: CacheStore<ScopedKey> {
    weak var parentCacheStore: CacheStore<Key>?
    private var keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>?
    
    init(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>
    ) {
        self.keyTransformation = keyTransformation
        
        super.init(initialValues: [:])
    }
    
    required init(initialValues: [ScopedKey: Any]) {
        super.init(initialValues: initialValues)
    }
    
    override func set<Value>(value: Value, forKey key: ScopedKey) {
        super.set(value: value, forKey: key)
        
        guard
            let keyTransformation = keyTransformation,
            let parentKey = keyTransformation.to(key)
        else { return }
        
        parentCacheStore?.set(value: value, forKey: parentKey)
    }
    
    override func update<Value>(_ key: ScopedKey, as: Value.Type = Value.self, updater: (inout Value?) -> Void) {
        <#code#>
    }
}
