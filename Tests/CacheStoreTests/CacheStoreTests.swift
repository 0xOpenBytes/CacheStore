import t
import XCTest
@testable import CacheStore

final class CacheStoreTests: XCTestCase {
    func testExample() throws {
        enum HashableKey: Hashable {
            case a, b, c
        }
        
        let cache = CacheStore<HashableKey>(
            initialValues: [
                .a: "a"
            ]
        )
        
        XCTAssert(
            t.suite {
                try t.assert(cache.resolve(.a), isEqualTo: "a")
            }
        )
        
        cache.set(value: "aa", forKey: .a)
        cache.set(value: "C", forKey: .c)
        
        XCTAssert(
            t.suite {
                try t.assert(cache.resolve(.a), isEqualTo: "aa")
                try t.assert(cache.resolve(.c), isEqualTo: "C")
            }
        )
    }
}
