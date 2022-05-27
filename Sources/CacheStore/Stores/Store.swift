import c
import Combine
import SwiftUI

// MARK: -

public class Store<Key: Hashable, Action, Dependency>: ObservableObject, ActionHandling {
    private var lock: NSLock
    private var isDebugging: Bool
    
    var cacheStore: CacheStore<Key>
    var actionHandler: StoreActionHandler<Key, Action, Dependency>
    let dependency: Dependency
    
    /// The values in the `cache` of type `Any`
    public var valuesInCache: [Key: Any] {
        defer { lock.unlock() }
        lock.lock()
        
        return cacheStore.valuesInCache
    }
    
    /// A publisher for the private `cache` that is mapped to a CacheStore
    public var publisher: AnyPublisher<CacheStore<Key>, Never> {
        defer { lock.unlock() }
        lock.lock()
        
        return cacheStore.publisher
    }
    
    /// An identifier of the Store and CacheStore
    var debugIdentifier: String {
        defer { lock.unlock() }
        lock.lock()
        
        let cacheStoreAddress = Unmanaged.passUnretained(cacheStore).toOpaque().debugDescription
        var storeDescription: String = "\(self)".replacingOccurrences(of: "CacheStore.", with: "")
        
        guard let index = storeDescription.firstIndex(of: "<") else {
            return "(Store: \(storeDescription), CacheStore: \(cacheStoreAddress))"
        }
        
        storeDescription = storeDescription[..<index].description // "Store"
        storeDescription += "<\(Key.self), \(Action.self), \(Dependency.self)>"
        
        return "(Store: \(storeDescription), CacheStore: \(cacheStoreAddress))"
    }
    
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency
    ) {
        lock = NSLock()
        isDebugging = false
        cacheStore = CacheStore(initialValues: initialValues)
        self.actionHandler = actionHandler
        self.dependency = dependency
    }
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
        defer { lock.unlock() }
        lock.lock()
        
        return cacheStore.get(key)
    }
    
    /// Resolve the value in the `cache` using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value is always in the `cache`.
    public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) -> Value {
        defer { lock.unlock() }
        lock.lock()
        
        return cacheStore.resolve(key)
    }
    
    /// Checks to make sure the cache has the required keys, otherwise it will throw an error
    @discardableResult
    public func require(keys: Set<Key>) throws -> Self {
        lock.lock()
        try cacheStore.require(keys: keys)
        lock.unlock()
        
        return self
    }
    
    /// Checks to make sure the cache has the required key, otherwise it will throw an error
    @discardableResult
    public func require(_ key: Key) throws -> Self {
        lock.lock()
        try cacheStore.require(keys: [key])
        lock.unlock()
        
        return self
    }
    
    public func handle(action: Action) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.handle(action: action)
            }
            return
        }
        
        lock.lock()
        
        if isDebugging {
            print("[\(formattedDate)] 🟡 New Action: \(action) \(debugIdentifier)")
        }
        
        var storeCopy = cacheStore.copy()
        if let effect = actionHandler.handle(store: &storeCopy, action: action, dependency: dependency) {
            Task {
                guard let nextAction = await effect() else { return }
                
                handle(action: nextAction)
            }
        }
        
        if isDebugging {
            print(
                """
                [\(formattedDate)] 📣 Handled Action: \(action) \(debugIdentifier)
                --------------- State Output ------------
                """
            )
        }
       
        if isCacheEqual(to: storeCopy) {
            if isDebugging {
                print("\t🙅 No State Change")
            }
        } else {
            if isDebugging {
                print(
                    """
                    \t⚠️ State Changed
                    \t\t--- Was ---
                    \t\t\(debuggingStateDelta(forUpdatedStore: cacheStore))
                    \t\t-----------
                    \t\t***********
                    \t\t--- Now ---
                    \t\t\(debuggingStateDelta(forUpdatedStore: storeCopy))
                    \t\t-----------
                    """
                )
            }
            
            objectWillChange.send()
            cacheStore.cache = storeCopy.cache
        }
        
        if isDebugging {
            print(
                """
                --------------- State End ---------------
                [\(formattedDate)] 🏁 End Action: \(action) \(debugIdentifier)
                """
            )
        }
        
        lock.unlock()
    }
    
    /// Checks if the given `key` has a value or not
    public func contains(_ key: Key) -> Bool {
        defer { lock.unlock() }
        lock.lock()
        
        return cacheStore.contains(key)
    }
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    public func valuesInCache<Value>(
        ofType type: Value.Type = Value.self
    ) -> [Key: Value] {
        defer { lock.unlock() }
        lock.lock()
        
        return cacheStore.valuesInCache(ofType: type)
    }
    
    /// Creates a `ScopedStore`
    public func scope<ScopedKey: Hashable, ScopedAction, ScopedDependency>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>,
        dependencyTransformation: (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil }
    ) -> Store<ScopedKey, ScopedAction, ScopedDependency> {
        let scopedStore = ScopedStore<Key, ScopedKey, Action, ScopedAction, Dependency, ScopedDependency> (
            initialValues: [:],
            actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>.none,
            dependency: dependencyTransformation(dependency)
        )
        
        defer { lock.unlock() }
        lock.lock()
        
        let scopedCacheStore = cacheStore.scope(
            keyTransformation: keyTransformation,
            defaultCache: defaultCache
        )
        
        scopedStore.cacheStore = scopedCacheStore
        scopedStore.parentStore = self
        scopedStore.actionHandler = StoreActionHandler { (store: inout CacheStore<ScopedKey>, action: ScopedAction, dependency: ScopedDependency) in
            let effect = actionHandler.handle(store: &store, action: action, dependency: dependency)
            
            if let parentAction = actionTransformation(action) {
                scopedStore.parentStore?.handle(action: parentAction)
            }
            
            return effect
        }
        
        cacheStore.cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedStore.cacheStore.cache[scopedKey] = value
        }
        
        return scopedStore
    }
    
    /// Creates an Actionless `ScopedStore`
    public func actionlessScope<ScopedKey: Hashable, ScopedDependency>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        dependencyTransformation: (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> Store<ScopedKey, Void, ScopedDependency> {
        scope(
            keyTransformation: keyTransformation,
            actionHandler: StoreActionHandler<ScopedKey, Void, ScopedDependency>.none,
            dependencyTransformation: dependencyTransformation,
            defaultCache: defaultCache,
            actionTransformation: { _ in nil }
        )
    }
    
    /// Creates a `Binding` for the given `Key` using an `Action` to set the value
    public func binding<Value>(
        _ key: Key,
        as: Value.Type = Value.self,
        using: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.resolve(key) },
            set: { self.handle(action: using($0)) }
        )
    }
    
    /// Creates a `Binding` for the given `Key`, where the value is Optional, using an `Action` to set the value
    public func optionalBinding<Value>(
        _ key: Key,
        as: Value.Type = Value.self,
        using: @escaping (Value?) -> Action
    ) -> Binding<Value?> {
        Binding(
            get: { self.get(key) },
            set: { self.handle(action: using($0)) }
        )
    }
}

// MARK: - Void Dependency

public extension Store {
    /// Creates a `ScopedStore`
    func scope<ScopedKey: Hashable, ScopedAction>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, Void>,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil }
    ) -> Store<ScopedKey, ScopedAction, Void> {
        scope(
            keyTransformation: keyTransformation,
            actionHandler: actionHandler,
            dependencyTransformation: { _ in () },
            defaultCache: defaultCache,
            actionTransformation: actionTransformation
        )
    }
    
    /// Creates a `ScopedStore`
    func actionlessScope<ScopedKey: Hashable>(
        keyTransformation: c.BiDirectionalTransformation<Key?, ScopedKey?>,
        defaultCache: [ScopedKey: Any] = [:]
    ) -> Store<ScopedKey, Void, Void> {
        actionlessScope(
            keyTransformation: keyTransformation,
            dependencyTransformation: { _ in () },
            defaultCache: defaultCache
        )
    }
}

// MARK: - Debugging

extension Store {
    public var debug: Self {
        lock.lock()
        isDebugging = true
        lock.unlock()
        
        return self
    }
    
    private var formattedDate: String {
        let now = Date()
        let formatter = DateFormatter()
        
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        return formatter.string(from: now)
    }

    private func isCacheEqual(to updatedStore: CacheStore<Key>) -> Bool {
        lock.lock()
        guard cacheStore.cache.count == updatedStore.cache.count else { return false }
        lock.unlock()
        
        return updatedStore.cache.map { key, value in
            isValueEqual(toUpdatedValue: value, forKey: key)
        }
        .reduce(into: true) { result, condition in
            guard condition else {
                result = false
                return
            }
        }
    }
    
    private func isValueEqual<Value>(toUpdatedValue updatedValue: Value, forKey key: Key) -> Bool {
        lock.lock()
        guard let storeValue: Value = cacheStore.get(key) else {
            return false
        }
        lock.unlock()
        
        return "\(updatedValue)" == "\(storeValue)"
    }
    
    private func debuggingStateDelta(forUpdatedStore updatedStore: CacheStore<Key>) -> String {
        var updatedStateChanges: [String] = []
        
        for (key, value) in updatedStore.valuesInCache {
            let isValueEqual: Bool = isValueEqual(toUpdatedValue: value, forKey: key)
            let valueInfo: String = "\(type(of: value))"
            let valueOutput: String
            
            if type(of: value) is AnyClass {
                valueOutput = "(\(Unmanaged.passUnretained(value as AnyObject).toOpaque().debugDescription))"
            } else {
                valueOutput = "= \(value)"
            }
            
            updatedStateChanges.append("\(isValueEqual ? "" : "+ ")\(key): \(valueInfo) \(valueOutput)")
        }
        
        return updatedStateChanges.joined(separator: "\n\t\t")
    }
}
