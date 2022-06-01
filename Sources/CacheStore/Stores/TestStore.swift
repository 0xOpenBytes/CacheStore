import Foundation
import XCTest

public class TestStore<Key: Hashable, Action, Dependency> {
    struct TestStoreEffect<Action> {
        let id: UUID
        let effect: () async -> Action?
    }
    
    public struct TestStoreError: LocalizedError {
        public let reason: String
        
        public var errorDescription: String? { reason }
    }
    
    private let initFile: StaticString
    private let initLine: UInt
    
    var store: Store<Key, Action, Dependency>
    var effects: [TestStoreEffect<Action>]
    var nextAction: Action?
    
    deinit {
        // XCT Execption
        guard effects.isEmpty else {
            let effectIDs = effects.map(\.id.uuidString).joined(separator: ", ")
            XCTFail("\(effects.count) effect(s) left to receive (\(effectIDs))", file: initFile, line: initLine)
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
            XCTAssert(false, file: file, line: line)
        }
        
        guard "\(expectedCacheStore.valuesInCache)" == "\(store.cacheStore.valuesInCache)" else {
            XCTFail(
                """
                \n--- Expected ---
                \(expectedCacheStore.valuesInCache)
                ----------------
                ****************
                ---- Actual ----
                \(store.cacheStore.valuesInCache)
                ----------------
                """,
                file: file,
                line: line
            )
            return
        }
        
        if let actionEffect = actionEffect {
            effects.append(TestStoreEffect(id: UUID(), effect: actionEffect.effect))
        }
    }
    
    public func receive(
        _ action: Action,
        file: StaticString = #filePath,
        line: UInt = #line,
        expecting: @escaping (inout CacheStore<Key>) throws -> Void
    ) {
        guard let effect = effects.first else {
            XCTFail("No effects to receive", file: file, line: line)
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
            XCTFail("Action (\(action)) does not equal NextAction (\(nextAction))", file: file, line: line)
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
            XCTFail("Store does not have requied keys (\(requiredKeys))", file: file, line: line)
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
            XCTFail("Store does not have requied key (\(key))", file: file, line: line)
        }
    }
}
