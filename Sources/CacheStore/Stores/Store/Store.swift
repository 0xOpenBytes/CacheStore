import Combine
import CustomDump
import SwiftUI

// MARK: -

/// An `ObservableObject` that uses actions to modify the state which is a `CacheStore`
open class Store<Key: Hashable, Action, Dependency>: ObservableObject, ActionHandling {
    private var lock: NSLock
    private var isDebugging: Bool
    private var cacheStoreObserver: AnyCancellable?
    private var effects: [AnyHashable: Task<(), Never>]
    private(set) var cacheStore: CacheStore<Key>
    private(set) var actionHandler: StoreActionHandler<Key, Action, Dependency>
    private let dependency: Dependency
    
    /// The values in the `cache` of type `Any`
    public var allValues: [Key: Any] {
        lock.lock()
        defer { lock.unlock() }
        
        return cacheStore.allValues
    }
    
    /// A publisher for the private `cache` that is mapped to a CacheStore
    public var publisher: AnyPublisher<CacheStore<Key>, Never> {
        lock.lock()
        defer { lock.unlock() }
        
        return cacheStore.publisher
    }
    
    /// An identifier of the Store and CacheStore
    public var debugIdentifier: String {
        lock.lock()
        defer { lock.unlock() }
        
        let cacheStoreAddress = Unmanaged.passUnretained(cacheStore).toOpaque().debugDescription
        var storeDescription: String = "\(self)".replacingOccurrences(of: "CacheStore.", with: "")
        
        guard let index = storeDescription.firstIndex(of: "<") else {
            return "(Store: \(storeDescription), CacheStore: \(cacheStoreAddress))"
        }
        
        storeDescription = storeDescription[..<index].description // "Store"
        storeDescription += "<\(Key.self), \(Action.self), \(Dependency.self)>"
        
        return "(Store: \(storeDescription), CacheStore: \(cacheStoreAddress))"
    }
    
    deinit {
        cacheStoreObserver?.cancel()
        effects.forEach { cancel(id: $0.key) }
    }
    
    /// init for `Store<Key, Action, Dependency>`
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency
    ) {
        lock = NSLock()
        isDebugging = false
        effects = [:]
        cacheStore = CacheStore(initialValues: initialValues)
        self.actionHandler = actionHandler
        self.dependency = dependency
        cacheStoreObserver = cacheStore.$cache
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
    
    /// Get the value in the `cache` using the `key`. This returns an optional value. If the value is `nil`, that means either the value doesn't exist or the value is not able to be casted as `Value`.
    public func get<Value>(_ key: Key, as: Value.Type = Value.self) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        
        return cacheStore.get(key)
    }
    
    /// Resolve the value in the `cache` using the `key`. This function uses `get` and force casts the value. This should only be used when you know the value is always in the `cache`.
    public func resolve<Value>(_ key: Key, as: Value.Type = Value.self) throws -> Value {
        lock.lock()
        defer { lock.unlock() }
        
        return try cacheStore.resolve(key)
    }
    
    /// Checks to make sure the cache has the required keys, otherwise it will throw an error
    @discardableResult
    public func require(keys: Set<Key>) throws -> Self {
        lock.lock()
        defer { lock.unlock() }
        
        try cacheStore.require(keys: keys)
        
        return self
    }
    
    /// Checks to make sure the cache has the required key, otherwise it will throw an error
    @discardableResult
    public func require(_ key: Key) throws -> Self {
        lock.lock()
        defer { lock.unlock() }
        
        try cacheStore.require(keys: [key])
        
        return self
    }
    
    /// Sends the action to be handled by the `Store`
    public func handle(action: Action) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handle(action: action)
            }
            return
        }
        
        _ = send(action)
    }
    
    /// Cancel an effect with the ID
    public func cancel(id: AnyHashable) {
        lock.lock()
        defer { lock.unlock() }

        effects[id]?.cancel()
        effects[id] = nil
    }
    
    /// Checks if the given `key` has a value or not
    public func contains(_ key: Key) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return cacheStore.contains(key)
    }
    
    /// Returns a Dictionary containing only the key value pairs where the value is the same type as the generic type `Value`
    public func valuesInCache<Value>(
        ofType type: Value.Type = Value.self
    ) -> [Key: Value] {
        lock.lock()
        defer { lock.unlock() }
        
        return cacheStore.valuesInCache(ofType: type)
    }
    
    /// Creates a `ScopedStore`
    public func scope<ScopedKey: Hashable, ScopedAction, ScopedDependency>(
        keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>,
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
        
        lock.lock()
        defer { lock.unlock() }
        
        let scopedCacheStore = cacheStore.scope(
            keyTransformation: keyTransformation,
            defaultCache: defaultCache
        )
        
        scopedStore.cacheStore = scopedCacheStore
        scopedStore.parentStore = self
        scopedStore.actionHandler = StoreActionHandler { [weak scopedStore] (store: inout CacheStore<ScopedKey>, action: ScopedAction, dependency: ScopedDependency) in
            let effect = actionHandler.handle(store: &store, action: action, dependency: dependency)
            
            if let parentAction = actionTransformation(action) {
                scopedStore?.parentStore?.handle(action: parentAction)
            }
            
            return effect
        }
        
        cacheStore.cache.forEach { key, value in
            guard let scopedKey = keyTransformation.from(key) else { return }
            
            scopedStore.cacheStore.cache[scopedKey] = value
        }
        
        return scopedStore
    }

    /// Creates a `ScopedStore`
    public func scope<Value, ScopedValue, ScopedKey: Hashable, ScopedAction, ScopedDependency>(
        keyValueTransformation: BiDirectionalTransformation<(Key, Value?)?, (ScopedKey, ScopedValue?)?>,
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

        lock.lock()
        defer { lock.unlock() }

        let scopedCacheStore = cacheStore.scope(
            keyValueTransformation: keyValueTransformation,
            defaultCache: defaultCache
        )

        scopedStore.cacheStore = scopedCacheStore
        scopedStore.parentStore = self
        scopedStore.actionHandler = StoreActionHandler { [weak scopedStore] (store: inout CacheStore<ScopedKey>, action: ScopedAction, dependency: ScopedDependency) in
            let effect = actionHandler.handle(store: &store, action: action, dependency: dependency)

            if let parentAction = actionTransformation(action) {
                scopedStore?.parentStore?.handle(action: parentAction)
            }

            return effect
        }

        cacheStore.cache.forEach { key, value in
            guard
                let transformation = keyValueTransformation.from((key, get(key, as: Value.self)))
            else { return }

            scopedStore.cacheStore.cache[transformation.0] = transformation.1
        }

        return scopedStore
    }
    
    /// Creates an Actionless `ScopedStore`
    public func actionlessScope<ScopedKey: Hashable, ScopedDependency>(
        keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>,
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
        fallback: Value,
        using: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { self.get(key) ?? fallback },
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

    /// Creates a `Binding` for the given `Key` using an `Action` to set the value
    public func binding<ParentValue, Value>(
        _ key: Key,
        as: ParentValue.Type = ParentValue.self,
        transform: @escaping (ParentValue?) -> Value,
        using: @escaping (Value) -> Action
    ) -> Binding<Value> {
        Binding(
            get: { transform(self.get(key, as: ParentValue.self)) },
            set: { self.handle(action: using($0)) }
        )
    }

    /// Creates a `Binding` for the given `Key`, where the value is Optional, using an `Action` to set the value
    public func optionalBinding<ParentValue, Value>(
        _ key: Key,
        as: Value.Type = Value.self,
        transform: @escaping (ParentValue?) -> Value?,
        using: @escaping (Value?) -> Action
    ) -> Binding<Value?> {
        Binding(
            get: { transform(self.get(key, as: ParentValue.self)) },
            set: { self.handle(action: using($0)) }
        )
    }
}

// MARK: - Void Dependency

public extension Store where Dependency == Void {
    /// init for `Store<Key, Action, Void>`
    convenience init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>
    ) {
        self.init(
            initialValues: initialValues,
            actionHandler: actionHandler,
            dependency: ()
        )
    }

    /// Creates a `ScopedStore`
    func scope<ScopedKey: Hashable, ScopedAction>(
        keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>,
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
        keyTransformation: BiDirectionalTransformation<Key?, ScopedKey?>,
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
    /// Modifies and returns the `Store` with debugging mode on
    public var debug: Self {
        lock.lock()
        isDebugging = true
        lock.unlock()
        
        return self
    }
    
    func send(_ action: Action) -> ActionEffect<Action>? {
        if isDebugging {
            print("[\(formattedDate)] 🟡 New Action: \(customDump(action)) \(debugIdentifier)")
        }
        
        var cacheStoreCopy = cacheStore.copy()
        
        let actionEffect = actionHandler.handle(store: &cacheStoreCopy, action: action, dependency: dependency)
        
        if let actionEffect = actionEffect {
            cancel(id: actionEffect.id)
            let effectTask = Task { [weak self] in
                defer { self?.cancel(id: actionEffect.id) }

                if Task.isCancelled { return }

                guard let nextAction = await actionEffect.effect() else { return }

                if Task.isCancelled { return }

                self?.handle(action: nextAction)
            }
            lock.lock()
            effects[actionEffect.id] = effectTask
            lock.unlock()
        }
        
        if isDebugging {
            print(
                """
                [\(formattedDate)] 📣 Handled Action: \(customDump(action)) \(debugIdentifier)
                --------------- State Output ------------
                """
            )

            if cacheStore.isCacheEqual(to: cacheStoreCopy) {
                print("\t🙅 No State Change")
            } else {
                if let diff = diff(cacheStore.cache, cacheStoreCopy.cache) {
                    print(
                        """
                        \t⚠️ State Changed
                        \(diff)
                        """
                    )
                } else {
                    print(
                        """
                        \t⚠️ State Changed
                        \t\t--- Was ---
                        \t\t\(debuggingStateDelta(forUpdatedStore: cacheStore))
                        \t\t-----------
                        \t\t***********
                        \t\t--- Now ---
                        \t\t\(debuggingStateDelta(forUpdatedStore: cacheStoreCopy))
                        \t\t-----------
                        """
                    )
                }
            }

            print(
                """
                --------------- State End ---------------
                [\(formattedDate)] 🏁 End Action: \(customDump(action)) \(debugIdentifier)
                """
            )
        }

        cacheStore.cache = cacheStoreCopy.cache
        
        return actionEffect
    }
    
    private var formattedDate: String {
        let now = Date()
        let formatter = DateFormatter()
        
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        
        return formatter.string(from: now)
    }
    
    private func debuggingStateDelta(forUpdatedStore updatedStore: CacheStore<Key>) -> String {
        lock.lock()
        defer { lock.unlock() }
        
        var updatedStateChanges: [String] = []
        
        for (key, value) in updatedStore.allValues {
            let isValueEqual: Bool = cacheStore.isValueEqual(toUpdatedValue: value, forKey: key)
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

extension Store {
    @ViewBuilder
    public func forEach<Value: Hashable, ScopedValue, ScopedKey: Hashable, ScopedAction, ScopedDependency>(
        _ key: Key,
        as type: Value.Type = Value.self,
        keyValueTransformation: BiDirectionalTransformation<(Key, Value?)?, (ScopedKey, ScopedValue?)?>,
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>,
        dependencyTransformation: @escaping (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil },
        noContentView: some View,
        content: @escaping (Store<ScopedKey, ScopedAction, ScopedDependency>) -> some View
    ) -> some View {
        if let data: [Value] = get(key) {
            ForEach(data, id: \.self) { datum in
                content(
                    self.scope(
                        keyValueTransformation: keyValueTransformation,
                        actionHandler: actionHandler,
                        dependencyTransformation: dependencyTransformation,
                        defaultCache: defaultCache,
                        actionTransformation: actionTransformation
                    )
                )
            }
        } else {
            noContentView
        }
    }
}
