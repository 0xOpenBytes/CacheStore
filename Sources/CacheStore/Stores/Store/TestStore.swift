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
open class TestStore<Key: Hashable, Action, Dependency> {
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
    public init(
        store: Store<Key, Action, Dependency>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        self.store = store
        effects = []
        initFile = file
        initLine = line
    }
    
    /// init for `TestStore<Key, Action, Dependency>`
    public required init(
        initialValues: [Key: Any],
        actionHandler: StoreActionHandler<Key, Action, Dependency>,
        dependency: Dependency,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        store = Store(initialValues: initialValues, actionHandler: actionHandler, dependency: dependency)
        effects = []
        initFile = file
        initLine = line
    }

    /// Modifies and returns the `TestStore` with debugging mode on
    public var debug: Self {
        _ = store.debug

        return self
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
                \(customDump(expectedCacheStore.allValues))
                ----------------
                ****************
                ---- Actual ----
                \(customDump(store.cacheStore.allValues))
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
    
    /// Create a StoreContent for the provided content type and make assertions in the expecting closure about the content
    public func content<Content: StoreContent>(
        using contentType: Content.Type = Content.self,
        expecting: @escaping (Content) throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where Content.Key == Key {
        do {
            try expecting(content(using: contentType))
        } catch {
            TestStoreFailure.handler("❌ Expectation failed: \(error)", file, line)
            return
        }
    }
    
    /// Create a StoreContent for the provided content type
    public func content<Content: StoreContent>(
        using contentType: Content.Type = Content.self
    ) -> Content where Content.Key == Key {
        store.content(using: contentType)
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
