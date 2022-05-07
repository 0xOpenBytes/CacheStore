import t
import XCTest
@testable import CacheStore

final class CacheStoreTests: XCTestCase {
    func testExample() throws {
        enum HashableKey: Hashable {
            case a, b, c
        }
        
        let store = CacheStore<HashableKey>(
            initialValues: [
                .a: "a"
            ]
        )
        
        XCTAssert(
            t.suite {
                try t.assert(store.resolve(.a), isEqualTo: "a")
            }
        )
        
        store.set(value: "aa", forKey: .a)
        store.set(value: "C", forKey: .c)
        
        XCTAssert(
            t.suite {
                try t.assert(store.resolve(.a), isEqualTo: "aa")
                try t.assert(store.resolve(.c), isEqualTo: "C")
            }
        )
    }
}
