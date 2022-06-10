#if DEBUG
import CustomDump
import Foundation
import XCTestDynamicOverlay

/// Facade typealias for XCTFail without importing XCTest
public typealias FailureHandler = (_ message: String, _ file: StaticString, _ line: UInt) -> Void

/// Static object to provide the `FailureHandler` to any `TestStore`
public enum TestStoreFailure {
    public static var handler: FailureHandler = XCTestDynamicOverlay.XCTFail
}

/// Testable `Store` where you can send and receive actions while expecting the changes
public class TestStore<Key: Hashable, Action, Dependency> {
    private let initFile: StaticString
    private let initLine: UInt
    private var nextAction: Action?
    private var store: Store<Key, Action, Dependency>
    private var effects: [ActionEffect<Action>]
    
    deinit {
        guard effects.isEmpty else {
            let effectIDs = effects.map { "- \($0.id)" }.joined(separator: "\n")
            TestStoreFailure.handler("❌ \(effects.count) effect(s) left to receive:\n\(effectIDs)", initFile, initLine)
            return
        }
    }
    
    /// init for `TestStore<Key, Action, Dependency>`
    ///
    /// **Make sure to set `TestStoreFailure.handler`**
    ///
    /// ```
    /// override func setUp() {
    ///     TestStoreFailure.handler = XCTFail
    /// }
    /// ```
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        store = Store(initialValues: initialValues, actionHandler: actionHandler, dependency: dependency).debug
        effects = []
        initFile = file
        initLine = line
    }
    
    /// Send an action and provide an expectation for the changes from handling the action
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
    
    /// Cancel a certain effect
    public func cancel(id: AnyHashable) {
        store.cancel(id: id)
    }
    
    /// Receive an action from the effects **FIFO** queue
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
        
        guard diff(action, nextAction) == nil else {
            TestStoreFailure.handler("❌ Action (\(customDump(action))) does not equal NextAction (\(customDump(nextAction)))", file, line)
            return
        }
        
        send(nextAction, file: file, line: line, expecting: expecting)
    }
    
    /// Checks to make sure the cache has the required keys, otherwise it will fail
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
    
    /// Checks to make sure the cache has the required key, otherwise it will fail
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
