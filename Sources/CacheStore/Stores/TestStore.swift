#if DEBUG
import CustomDump
import Foundation

public typealias FailureHandler = (_ message: String, _ file: StaticString, _ line: UInt) -> Void

public enum TestStoreFailure {
    public static var handler: FailureHandler!
}

public class TestStore<Key: Hashable, Action, Dependency> {
    private let initFile: StaticString
    private let initLine: UInt
    private var nextAction: Action?
    
    public private(set) var store: Store<Key, Action, Dependency>
    public private(set) var effects: [ActionEffect<Action>]
    
    deinit {
        guard effects.isEmpty else {
            let effectIDs = effects.map { "- \($0.id)" }.joined(separator: "\n")
            TestStoreFailure.handler("❌ \(effects.count) effect(s) left to receive:\n\(effectIDs)", initFile, initLine)
            return
        }
    }
    
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assert(
            TestStoreFailure.handler != nil,
            """
            Set `TestStoreFailure.handler`
                
                override func setUp() {
                    TestStoreFailure.handler = XCTFail
                }
            
            """
        )
        
        store = Store(initialValues: initialValues, actionHandler: actionHandler, dependency: dependency).debug
        effects = []
        initFile = file
        initLine = line
    }
    
    public func send(
        _ action: Action,
        file: StaticString = #filePath,
        line: UInt = #line,
        expecting: (inout CacheStore<Key>) throws -> Void
    ) {
        var expectedCacheStore = store.cacheStore.copy()
        
        let actionEffect = store.send(action)
        
        do {
            try expecting(&expectedCacheStore)
        } catch {
            TestStoreFailure.handler("❌ Expectation failed", file, line)
            return
        }
        
        guard expectedCacheStore.isCacheEqual(to: store.cacheStore) else {
            TestStoreFailure.handler(
                """
                ❌ Expectation failed
                --- Expected ---
                \(customDump(expectedCacheStore.valuesInCache))
                ----------------
                ****************
                ---- Actual ----
                \(customDump(store.cacheStore.valuesInCache))
                ----------------
                """,
                file,
                line
            )
            return
        }
        
        
        if let actionEffect = actionEffect {
            let predicate: (ActionEffect<Action>) -> Bool = { $0.id == actionEffect.id }
            if effects.contains(where: predicate) {
                effects.removeAll(where: predicate)
            }
            
            effects.append(actionEffect)
        }
    }
    
    public func receive(
        _ action: Action,
        file: StaticString = #filePath,
        line: UInt = #line,
        expecting: @escaping (inout CacheStore<Key>) throws -> Void
    ) {
        guard let effect = effects.first else {
            TestStoreFailure.handler("❌ No effects to receive", file, line)
            return
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
            TestStoreFailure.handler("❌ Action (\(customDump(action))) does not equal NextAction (\(customDump(nextAction)))", file, line)
            return
        }
        
        send(nextAction, expecting: expecting)
    }
}


public extension TestStore {
    func require(
        keys: Set<Key>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try store.require(keys: keys)
        } catch {
            let requiredKeys = keys.map { "\($0)" }.joined(separator: ", ")
            TestStoreFailure.handler("❌ Store does not have requied keys (\(requiredKeys))", file, line)
        }
    }
    
    func require(
        _ key: Key,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try store.require(key)
        } catch {
            TestStoreFailure.handler("❌ Store does not have requied key (\(key))", file, line)
        }
    }
}
#endif
