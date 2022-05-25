import t
import c
import XCTest
@testable import CacheStore

class StoreTests: XCTestCase {
    func testExample() {
        XCTAssert(
            t.suite(named: "Testing Store") {
                struct SomeStruct {
                    var value: String
                    var otherValue: String
                }
                
                class SomeClass {
                    var value: String
                    var otherValue: String
                    
                    init(value: String, otherValue: String) {
                        self.value = value
                        self.otherValue = otherValue
                    }
                }
                
                enum StoreKey {
                    case isOn
                    case someStruct
                    case someClass
                }
                
                enum Action {
                    case toggle, nothing, removeValue, updateStruct, updateClass
                }
                
                let actionHandler = StoreActionHandler<StoreKey, Action, Void> { (store: inout CacheStore<StoreKey>, action: Action, _: Void) in
                    switch action {
                    case .toggle:
                        store.update(.isOn, as: Bool.self, updater: { $0?.toggle() })
                    case .nothing:
                        print("Do nothing")
                    case .removeValue:
                        store.remove(.someStruct)
                    case .updateStruct:
                        store.update(.someStruct, as: SomeStruct.self, updater: { $0?.otherValue = "something" })
                    case .updateClass:
                        store.update(.someClass, as: SomeClass.self, updater: { $0?.otherValue = "something else" })
                    }
                }
                
                let store = try Store<StoreKey, Action, Void>(
                    initialValues: [
                        .isOn: false,
                        .someStruct: SomeStruct(value: "init-struct", otherValue: "other"),
                        .someClass: SomeClass(value: "init-class", otherValue: "other"),
                    ],
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
                
                store.handle(action: .updateStruct)
                
                // No state changes for Referance Types
                store.handle(action: .updateClass)
                
                store.handle(action: .removeValue)
            }
        )
    }
}t
