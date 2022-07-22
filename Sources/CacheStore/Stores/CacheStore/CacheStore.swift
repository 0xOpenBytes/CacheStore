import c
import Combine
import CustomDump
import SwiftUI

// MARK: -

/// An `ObservableObject` that has a `cache` which is the source of truth for this object
open class CacheStore<Key: Hashable>: ObservableObject, Cacheable {
    /// `Error` that reports the missing keys for the `CacheStore`
    public struct MissingRequiredKeysError<Key: Hashable>: LocalizedError {
        /// Required keys
        public let keys: Set<Key>
        
        /// init for `MissingRequiredKeysError<Key>`
        public init(keys: Set<Key>) {
            self.keys = keys
        }
        
        /// Error description for `LocalizedError`
        public var errorDescription: String? {
            "Missing Required Keys: \(keys.map { "\($0)" }.joined(separator: ", "))"
        }
    }
    
    private var lock: NSLock
    @Published var cache: [Key: Any]
    
    /// The values in the `cache` of type `Any`
    public var valuesInCache: [Key: Any] { cache }
    
    /// init for `CacheStore<Key>`
    required public init(initialValues: [Key: Any]) {
        lock = NSLock()
        cache = initialValues
    }
    
    /// Get the `Value` for the `Key` if it exists
    public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
        defer { lock.unlock() }
        lock.lock()
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
    
    /// Resolve the `Value` for the `Key` by force casting `get`
    public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) -> Value { get(key)! }
    
    /// Set the `Value` for the `Key`
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
    
    /// Require a set of keys otherwise throw an error
    @discardableResult
    public func require(keys: Set<Key>) throws -> Self {
        let missingKeys = keys
            .filter { contains($0) == false }
        
        guard missingKeys.isEmpty else {
            throw MissingRequiredKeysError(keys: missingKeys)
        }
        
        return self
    }
    
    /// Require a key otherwise throw an error
    @discardableResult
    public func require(_ key: Key) throws -> Self {
        try require(keys: [key])
    }
    
    /// Check to see if the cache contains a key
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return cache[key] != nil
    }
    
    /// Get the values in the cache that are of the type `Value`
    public func valuesInCache<Value>(
        ofType: Value.Type = Value.self
    ) -> [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        
        return cache.compactMapValues { $0 as? Value }
    }
    
    /// Update the value of a key by mutating the value passed into the `updater` parameter
    public func update<Value>(
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
    
    /// Remove the value for the key
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
    
    // MARK: - Copying
    
    /// Create a copy of the current `CacheStore` cache
    public func copy() -> CacheStore {
        lock.lock()
        defer { lock.unlock() }
        
        return CacheStore(initialValues: cache)
    }
}

// MARK: -

public extension CacheStore {
    /// A publisher for the private `cache` that is mapped to a CacheStore
    var publisher: AnyPublisher<CacheStore, Never> {
        lock.lock()
        defer { lock.unlock() }
        
        return $cache.map(CacheStore.init).eraseToAnyPublisher()
    }
    
    /// Creates a `ScopedCacheStore` with the given key transformation and default cache
    func scope<ScopedKey: Hashable>(
        keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> CacheStore<ScopedKey> {
        let scopedCacheStore = ScopedCacheStore(keyTransformation: keyTransformation)
        
        scopedCacheStore.cache = defaultCache
        scopedCacheStore.parentCacheStore = self
        
        lock.lock()
        cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedCacheStore.cache[scopedKey] = value
        }
        lock.unlock()
        
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

extension CacheStore {
    func isCacheEqual(to updatedStore: CacheStore<Key>) -> Bool {
        lock.lock()
        let cacheStoreCount = cache.count
        lock.unlock()
        
        guard cacheStoreCount == updatedStore.cache.count else { return false }
        
        return updatedStore.cache.map { key, value -> Bool in
            let mirror = Mirror(reflecting: value)
            
            if mirror.displayStyle != .optional {
                return isValueEqual(toUpdatedValue: value, forKey: key)
            }
            
            if mirror.children.isEmpty {
                return (try? require(key)) == nil
            }
            
            guard
                let (_, unwrappedValue) = mirror.children.first
            else { return (try? require(key)) == nil }
            
            return isValueEqual(toUpdatedValue: unwrappedValue, forKey: key)
            
        }
        .reduce(into: true) { result, condition in
            guard condition else {
                result = false
                return
            }
        }
    }
    
    func isValueEqual<Value>(toUpdatedValue updatedValue: Value, forKey key: Key) -> Bool {
        guard let storeValue: Value = get(key) else {
            return false
        }
        
        if let isCollectionEqual = isCollection(storeValue: storeValue, equalToUpdatedValue: updatedValue) {
            return isCollectionEqual
        }
        
        return "\(updatedValue)" == "\(storeValue)"
    }
    
    func isCollection<Value>(storeValue: Value, equalToUpdatedValue updatedValue: Value) -> Bool? {
        if
            let storeValueCollection = storeValue as? [Any],
            let updateValueCollection = updatedValue as? [Any]
        {
            let sortedStoreCollection = storeValueCollection.sorted(by: { "\($0)" < "\($1)" })
            let sortedUpdatedStoreCollection = updateValueCollection.sorted(by: { "\($0)" < "\($1)" })
            
            return diff(sortedStoreCollection, sortedUpdatedStoreCollection) == nil
        }
        else if
            let storeValueCollection = storeValue as? [AnyHashable: Any],
            let updateValueCollection = updatedValue as? [AnyHashable: Any]
        {
            let sortedStoreCollection = storeValueCollection.sorted(by: { "\($0.key)" < "\($1.key)" })
            let sortedUpdatedStoreCollection = updateValueCollection.sorted(by: { "\($0.key)" < "\($1.key)" })
            
            return diff(sortedStoreCollection, sortedUpdatedStoreCollection) == nil
        }
        else if
            let storeValueCollection = storeValue as? Set<AnyHashable>,
            let updateValueCollection = updatedValue as? Set<AnyHashable>
        {
            let sortedStoreCollection = storeValueCollection.sorted(by: { "\($0)" < "\($1)" })
            let sortedUpdatedStoreCollection = updateValueCollection.sorted(by: { "\($0)" < "\($1)" })
            
            return diff(sortedStoreCollection, sortedUpdatedStoreCollection) == nil
        }
        
        return nil
    }
}
