//
//  ScopedKeyValueCacheStore.swift
//  
//
//  Created by Leif on 11/2/22.
//

class ScopedKeyValueCacheStore<Key: Hashable, Value, ScopedKey: Hashable, ScopedValue>: CacheStore<ScopedKey> {
    weak var parentCacheStore: CacheStore<Key>?
    private var keyValueTransformation: BiDirectionalTransformation<(Key, Value?)?, (ScopedKey, ScopedValue?)?>

    init(
        keyValueTransformation: BiDirectionalTransformation<(Key, Value?)?, (ScopedKey, ScopedValue?)?>
    ) {
        self.keyValueTransformation = keyValueTransformation

        super.init(initialValues: [:])
    }

    required init(initialValues: [ScopedKey: Any]) { fatalError("Not implemented") }

    override func set<Value>(value: Value, forKey key: ScopedKey) {
        super.set(value: value, forKey: key)

        guard let transformation = keyValueTransformation.to((key, get(key))) else { return }

        parentCacheStore?.set(value: transformation.1, forKey: transformation.0)
    }

    override func copy() -> ScopedKeyValueCacheStore<Key, Value, ScopedKey, ScopedValue> {
        let scopedCacheStore = ScopedKeyValueCacheStore<Key, Value, ScopedKey, ScopedValue>(keyValueTransformation: keyValueTransformation)

        scopedCacheStore.cache = cache
        scopedCacheStore.parentCacheStore = parentCacheStore

        return scopedCacheStore
    }
}
