import t
import c
import XCTest
@testable import CacheStore

final class CacheStoreTests: XCTestCase {
    func testExample() throws {
        enum HashableKey: Hashable {
            case a, b, c
        }
        
        let store = CacheStore<HashableKey>(
            initialValues: [
                .a: "a",
                .b: false
            ]
        )
        
        XCTAssert(
            t.suite {
                try t.assert(store.resolve(.a), isEqualTo: "a")
            }
        )
        
        
        store.set(value: "aa", forKey: .a)
        store.update(.c) { value in
            value = "C"
        }
        
        store.update(.b, as: Bool.self, updater: { $0?.toggle() })
        
        XCTAssert(
            t.suite {
                try t.assert(store.resolve(.a), isEqualTo: "aa")
                try t.assert(store.resolve(.c), isEqualTo: "C")
                try t.assert(store.resolve(.b), isEqualTo: true)
            }
        )
    }
    
    func testGet() {
        enum CacheKey {
            case missingValue
            case value
        }
        
        let store = CacheStore<CacheKey>(
            initialValues: [
                .value: 10
            ]
        )
        
        XCTAssert(
            t.suite(named: "Get Tests") {
                let missingValue: Int? = store.get(.missingValue)
                let value: Int? = store.get(.value)
                
                try t.expect {
                    try t.assert(isNil: missingValue)
                    try t.assert(isNotNil: value)
                    try t.assert(value, isEqualTo: store.resolve(.value))
                }
            }
        )
    }
    
    func testSet() {
        enum CacheKey {
            case missingValue
            case value
        }
        
        let store = CacheStore<CacheKey>(
            initialValues: [
                .value: true
            ]
        )
        
        XCTAssert(
            t.suite(named: "Set Tests") {
                let initialValue: Bool? = store.get(.value)
                
                store.set(value: false, forKey: .value)
                    
                let missingValue: Bool? = store.get(.missingValue)
                let value: Bool? = store.get(.value)
                
                try t.expect {
                    try t.assert(isNil: missingValue)
                    try t.assert(isNotNil: value)
                    try t.assert(value, isNotEqualTo: initialValue)
                }
            }
        )
    }
    
    func testRemove() {
        enum CacheKey {
            case missingValue
            case value
        }
        
        let store = CacheStore<CacheKey>(
            initialValues: [
                .value: 10
            ]
        )
        
        XCTAssert(
            t.suite(named: "Remove Tests") {
                let value: Int? = store.get(.value)
                
                try t.expect {
                    try t.assert(isNotNil: value)
                    
                    store.remove(.value)
                    
                    try t.assert(isNil: store.get(.value, as: Int.self))
                }
            }
        )
    }
    
    func testScopedCacheStore() {
        enum CacheKey {
            case a
            case b
        }
        
        let store = CacheStore<CacheKey>(
            initialValues: [
                .a: "Red",
                .b: "Blue"
            ]
        )
        
        enum ScopedCacheKey {
            case b
            case c
        }
        
        let scopedCacheStore: CacheStore<ScopedCacheKey> = store.scope(
            keyTransformation: c.transformer(
                from: { global in
                    switch global {
                    case .b: return .b
                    default: return nil
                    }
                },
                to: { local in
                    switch local {
                    case .b: return .b
                    default: return nil
                    }
                }
            ),
            defaultCache: [
                .c: "Green"
            ]
        )
        
        XCTAssert(
            t.suite(named: "Scope Tests") {
                try t.expect("that store's b and scopedStore's b are the same and should update together.") {
                    
                    let storeValue: String = store.resolve(.b)
                    let scopeValue: String = scopedCacheStore.resolve(.b)
                    
                    try t.assert(storeValue, isEqualTo: scopeValue)
                    try t.assert(storeValue, isEqualTo: "Blue")
                    try t.assert(scopeValue, isEqualTo: "Blue")
                    
                    t.log("ScopedCacheStore Setting b value")
                    
                    scopedCacheStore.set(value: "Purple", forKey: .b)
                
                    let scopedCacheUpdatedStoreValue: String = store.resolve(.b)
                    let scopedCacheUpdatedScopeValue: String = scopedCacheStore.resolve(.b)
                    
                    try t.assert(scopedCacheUpdatedStoreValue, isEqualTo: scopedCacheUpdatedScopeValue)
                    try t.assert(scopedCacheUpdatedStoreValue, isEqualTo: "Purple")
                    try t.assert(scopedCacheUpdatedScopeValue, isEqualTo: "Purple")
                    
                    t.log("Store Setting b value")

                    store.set(value: "Yellow", forKey: .b)

                    let storeUpdatedStoreValue: String = store.resolve(.b)
                    let storeOldScopeValue: String = scopedCacheStore.resolve(.b)
                    
                    let newlyScopedCacheStore: CacheStore<ScopedCacheKey> = store.scope(
                        keyTransformation: c.transformer(
                            from: { global in
                                switch global {
                                case .b: return .b
                                default: return nil
                                }
                            },
                            to: { local in
                                switch local {
                                case .b: return .b
                                default: return nil
                                }
                            }
                        ),
                        defaultCache: [
                            .c: "Green"
                        ]
                    )
                    let storeNewScopeValue: String = newlyScopedCacheStore.resolve(.b)
                    
                    try t.assert(storeUpdatedStoreValue, isNotEqualTo: storeOldScopeValue)
                    try t.assert(storeUpdatedStoreValue, isEqualTo: storeNewScopeValue)
                    
                    try t.assert(storeUpdatedStoreValue, isEqualTo: "Yellow")
                    try t.assert(storeNewScopeValue, isEqualTo: "Yellow")
                    try t.assert(storeOldScopeValue, isEqualTo: "Purple")
                }
            }
        )
    }
}
