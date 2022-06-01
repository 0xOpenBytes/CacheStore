import t
import c
import XCTest
@testable import CacheStore

class StoreTests: XCTestCase {
    func testExample() {
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
                
                print("TOGGLE HERE: \(Date())")
                
                return ActionEffect(id: "toggle->nothing") {
                    sleep(3)
                    return .nothing
                }
                
            case .nothing:
                print("NOTHING HERE: \(Date())")
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
        
        let store = TestStore<StoreKey, Action, Void>(
            initialValues: [
                .isOn: false,
                .someStruct: SomeStruct(value: "init-struct", otherValue: "other"),
                .someClass: SomeClass(value: "init-class", otherValue: "other"),
            ],
            actionHandler: actionHandler,
            dependency: ()
        )
        
        store.require(.isOn)
        
        store.send(.toggle, expecting: { $0.set(value: true, forKey: .isOn) })
        store.receive(.nothing, expecting: { _ in })
        
        store.send(.toggle, expecting: { $0.set(value: false, forKey: .isOn) })
        store.receive(.nothing, expecting: { _ in })
        
        store.send(.updateStruct, expecting: {
            $0.update(.someStruct, as: SomeStruct.self, updater: { $0?.otherValue = "something" })
        })
        
        // Class changes are ignored due to being reference types
        store.send(.updateClass, expecting: { _ in })
        
        store.send(.removeValue, expecting: { $0.remove(.someStruct) })
        
        
        print("TEST COMPLETE")
    }
}
