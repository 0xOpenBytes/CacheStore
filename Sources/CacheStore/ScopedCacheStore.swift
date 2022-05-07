import c

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
