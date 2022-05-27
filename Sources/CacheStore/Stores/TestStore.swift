import Foundation

public class TestStore<Key: Hashable, Action, Dependency> {
    struct TestStoreEffect<Action> {
        let id: UUID
        let effect: () async -> Action?
    }
    
    struct TestStoreError: LocalizedError {
        let reason: String
        
        var errorDescription: String? {
            reason
        }
    }
    
    var store: Store<Key, Action, Dependency>
    var effects: [TestStoreEffect<Action>]
    var nextAction: Action?
    
    deinit {
        // XCT Execption
        guard effects.isEmpty else {
            print("Uh Oh! We still have \(effects.count) effects!")
            return
        }
    }
    
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency
    ) {
        store = Store(initialValues: initialValues, actionHandler: actionHandler, dependency: dependency)
        effects = []
    }
    
    public func send(_ action: Action, expecting: (inout CacheStore<Key>) throws -> Void) throws {
        var expectedCacheStore = store.cacheStore.copy()
        
        let effect = store.actionHandler.handle(
            store: &store.cacheStore,
            action: action,
            dependency: store.dependency
        )
        
        try expecting(&expectedCacheStore)
        
        guard "\(expectedCacheStore.valuesInCache)" == "\(store.cacheStore.valuesInCache)" else {
            throw TestStoreError(
                reason: """
                \n--- Expected ---
                \(expectedCacheStore.valuesInCache)
                ----------------
                ****************
                ---- Actual ----
                \(store.cacheStore.valuesInCache)
                ----------------
                """
            )
        }
        
        if let effect = effect {
            effects.append(TestStoreEffect(id: UUID(), effect: effect))
        }
    }
    
    public func receive(_ action: Action, expecting: @escaping (inout CacheStore<Key>) throws -> Void) throws {
        guard let effect = effects.first else {
            throw TestStoreError(reason: "No effects to receive")
        }
        
        effects.removeFirst()
        
        let sema = DispatchSemaphore(value: 0)
        
        Task {
            nextAction = await effect.effect()
            sema.signal()
        }
        
        sema.wait()
        
        guard let nextAction = nextAction else {
            return
        }
        
        guard "\(action)" == "\(nextAction)" else {
            throw TestStoreError(reason: "Action (\(action)) does not equal NextAction (\(nextAction))")
        }
        
        try self.send(nextAction, expecting: expecting)
    }
}

public extension TestStore {
    func require(keys: Set<Key>) throws -> Self {
        try store.require(keys: keys)
        
        return self
    }
    
    func require(_ key: Key) throws -> Self {
        try store.require(key)
        
        return self
    }
}
