import t
import c
import XCTest
@testable import CacheStore

class StoreTests: XCTestCase {
    func testExample() {
        XCTAssert(
            t.suite(named: "Testing Store") {
                enum StoreKey {
                    case isOn
                }
                
                enum Action {
                    case toggle
                }
                
                let actionHandler = StoreActionHandler<StoreKey, Action, Void> { (store: inout CacheStore<StoreKey>, action: Action, _: Void) in
                    switch action {
                    case .toggle:
                        store.update(.isOn, as: Bool.self, updater: { $0?.toggle() })
                    }
                }
                
                let store = Store<StoreKey, Action, Void>(
                    initialValues: [.isOn: false],
                    actionHandler: actionHandler,
                    dependency: ()
                )
                
                try t.assert(store.get(.isOn), isEqualTo: false)
                
                store.handle(action: .toggle)
                
                try t.assert(store.get(.isOn), isEqualTo: true)
            }
        )
    }
}
