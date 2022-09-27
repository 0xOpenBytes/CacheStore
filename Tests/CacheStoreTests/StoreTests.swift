import t
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
    
    func testCollections() {
        enum StoreKey {
            case array
            case dictionary
            case set
            case tuple
            case triple
        }
        
        enum StoreAction {
            case setArray([Any])
            case setDictionary([AnyHashable: Any])
            case setSet(Set<AnyHashable>)
            case setTuple((Any, Any))
            case setTriple((Any, Any, Any))
        }
        
        let storeActionHandler = StoreActionHandler<StoreKey, StoreAction, Void> { cacheStore, action, _ in
            switch action {
            case let .setArray(array): cacheStore.set(value: array, forKey: .array)
            case let .setDictionary(dictionary): cacheStore.set(value: dictionary, forKey: .dictionary)
            case let .setSet(set): cacheStore.set(value: set, forKey: .set)
            case let .setTuple(tuple): cacheStore.set(value: tuple, forKey: .tuple)
            case let .setTriple(triple): cacheStore.set(value: triple, forKey: .triple)
            }
            
            return .none
        }
        
        let store = TestStore(
            initialValues: [:],
            actionHandler: storeActionHandler,
            dependency: ()
        )
        
        for _ in 0 ... 99 {
            let randomExpectedArray: [Any] = [Int.random(in: -100 ... 100), "Hello, World!", Double.random(in: 0 ... 1)]
            store.send(.setArray(randomExpectedArray)) { cacheStore in
                cacheStore.set(value: randomExpectedArray.shuffled(), forKey: .array)
            }
            
            let randomExpectedDictionary: [AnyHashable: Any] = [
                "Hello, World!": 27,
                Double.pi: "Hello, World!",
                false: true
            ]
            let shuffledExpectedDictionary: [AnyHashable: Any] = [
                false: true,
                "Hello, World!": 27,
                Double.pi: "Hello, World!",
            ]
            store.send(.setDictionary(randomExpectedDictionary)) { cacheStore in
                cacheStore.set(value: shuffledExpectedDictionary, forKey: .dictionary)
            }
            
            let randomExpectedSet: Set<AnyHashable> = [Int.random(in: -100 ... 100), "Hello, World!", Double.random(in: 0 ... 1)]
            store.send(.setSet(randomExpectedSet)) { cacheStore in
                cacheStore.set(value: randomExpectedSet, forKey: .set)
            }
            
            let randomExpectedTuple: (Any, Any) = (Bool.random(), Int.random(in: -100 ... 100))
            store.send(.setTuple(randomExpectedTuple)) { cacheStore in
                cacheStore.set(value: randomExpectedTuple, forKey: .tuple)
            }
            
            let randomExpectedTriple: (Any, Any, Any) = (Double.random(in: 0 ... 1), Int.random(in: -100 ... 100), Bool.random())
            store.send(.setTriple(randomExpectedTriple)) { cacheStore in
                cacheStore.set(value: randomExpectedTriple, forKey: .triple)
            }
        }
    }
}
