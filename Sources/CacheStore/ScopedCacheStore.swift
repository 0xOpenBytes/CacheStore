import c

public class ScopedCacheStore<Key: Hashable, ScopedKey: Hashable>: CacheStore<ScopedKey> {
    weak var parentCacheStore: CacheStore<Key>?
    private var keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>?
    
    init(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>
    ) {
        self.keyTransformation = keyTransformation
        
        super.init(initialValues: [:])
    }
    
    required public init(initialValues: [ScopedKey: Any]) {
        super.init(initialValues: initialValues)
    }
    
    override public func set<Value>(value: Value, forKey key: ScopedKey) {
        
        guard
            let keyTransformation = keyTransformation,
            let parentKey = keyTransformation.to(key)
        else { return }
        
        parentCacheStore?.set(value: value, forKey: parentKey)
    }
}
