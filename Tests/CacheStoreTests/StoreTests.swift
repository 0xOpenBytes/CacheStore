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
                    case someRandomValue
                }
                
                enum Action {
                    case toggle, nothing
                }
                
                let actionHandler = StoreActionHandler<StoreKey, Action, Void> { (store: inout CacheStore<StoreKey>, action: Action, _: Void) in
                    switch action {
                    case .toggle:
                        store.update(.isOn, as: Bool.self, updater: { $0?.toggle() })
                    case .nothing:
                        print("Do nothing")
                    }
                }
                
                let store = try Store<StoreKey, Action, Void>(
                    initialValues: [.isOn: false, .someRandomValue: "???"],
                    actionHandler: actionHandler,
                    dependency: ()
                )
                    .require(.isOn)
                    .debug
                
                try t.assert(store.contains(.isOn), isEqualTo: true)
                try t.assert(store.get(.isOn), isEqualTo: false)
                
                store.handle(action: .toggle)
                store.handle(action: .nothing)
                
                try t.assert(store.get(.isOn), isEqualTo: true)
            }
        )
    }
}
