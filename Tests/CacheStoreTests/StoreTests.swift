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
                    case rtandom
                }
                
                enum Action {
                    case toggle, nothing, removeValue, updateStruct, updateClass
                }
                
                let actionHandler = StoreActionHandler<StoreKey, Action, Void> { (store: inout CacheStore<StoreKey>, action: Action, _: Void) in
                    switch action {
                    case .toggle:
                        store.update(.isOn, as: Bool.self, updater: { $0?.toggle() })
                        
                        print("HERE: \(Date())")
                        
                        return {
                            sleep(3)
                            return .nothing
                        }
                    case .nothing:
                        print("HERE: \(Date())")
                        print("Do nothing")
                    case .removeValue:
                        store.remove(.someStruct)
                    case .updateStruct:
                        store.update(.someStruct, as: SomeStruct.self, updater: { $0?.otherValue = "something" })
                    case .updateClass:
                        store.update(.someClass, as: SomeClass.self, updater: { $0?.otherValue = "something else" })
                    }
                    
                    return .none
                }
                
                let store = try TestStore<StoreKey, Action, Void>(
                    initialValues: [
                        .isOn: false,
                        .someStruct: SomeStruct(value: "init-struct", otherValue: "other"),
                        .someClass: SomeClass(value: "init-class", otherValue: "other"),
                    ],
                    actionHandler: actionHandler,
                    dependency: ()
                )
                    .require(keys: [.rtandom, .isOn])
                
                try store.send(.toggle, expecting: { $0.set(value: true, forKey: .isOn) })
                
                try store.receive(.nothing, expecting: { _ in })
  
                try store.send(.updateStruct, expecting: {
                    $0.update(.someStruct, as: SomeStruct.self, updater: { $0?.otherValue = "something" })
                })
                
                // Class changes are ignored due to being reference types
                try store.send(.updateClass, expecting: { _ in })
                
                try store.send(.removeValue, expecting: { $0.remove(.someStruct) })
            }
        )
    }
}
