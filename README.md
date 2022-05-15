# CacheStore

*SwiftUI Observable Cache*

## What is `CacheStore`?

`CacheStore` is a SwiftUI framework to help with state. Define keyed values that you can share locally or globally in your projects. `CacheStore` uses [`c`](https://github.com/0xOpenBytes/c), which a simple composition framework. [`c`](https://github.com/0xOpenBytes/c) has the ability to create transformations that are either unidirectional or bidirectional. There is also a cache that values can be set and resolved, which is used in `CacheStore`.

## Objects 
- `CacheStore`: An object that needs a defined Key to get and set values.
- `Store`: An object that needs a defined Key, Actions, and Dependencies. (Preferred)

## Store

A `Store` is an object that you send actions to and read state from. Stores use a private `CacheStore` to manage state behind the scenes. All state changes must be defined in a `StoreActionHandler` where the state gets modified depending on an action.

## Basic Store Example

Here is a basic `Store` example where this is a Boolean variable called `isOn`. The only way you can modify that variable is be using defined actions for the given store. In this example there is only one action, toggle. 

```swift
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
```

## Basic CacheStore Example

Here is a simple application that has two files, an `App` file and `ContentView` file. The `App` contains the `StateObject` `CacheStore`. It then adds the `CacheStore` to the global cache using [`c`](https://github.com/0xOpenBytes/c). `ContentView` can then resolve the cache as an `ObservableObject` which can read or write to the cache. The cache can be injected into the `ContentView` directly, see `ContentView_Previews`, or indirectly, see `ContentView`.

```swift
import c
import CacheStore
import SwiftUI

enum CacheKey: Hashable {
    case someValue
}

@main
struct DemoApp: App {
    @StateObject var cacheStore = CacheStore<CacheKey>(
        initialValues: [.someValue: "🥳"]
    )
    
    var body: some Scene {
        c.set(value: cacheStore, forKey: "CacheStore")
        
        return WindowGroup {
            VStack {
                Text("@StateObject value: \(cacheStore.resolve(.someValue) as String)")
                ContentView()
            }
        }
    }
}

```

### ContentView

```swift
import c
import CacheStore
import SwiftUI

struct ContentView: View {
    @ObservedObject var cacheStore: CacheStore<CacheKey> = c.resolve("CacheStore")
    
    var stringValue: String {
        cacheStore.resolve(.someValue)
    }
    
    var body: some View {
        VStack {
            Text("Current Value: \(stringValue)")
            Button("Update Value") {
                cacheStore.set(value: ":D", forKey: .someValue)
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            cacheStore: CacheStore(
                initialValues: [.someValue: "Preview Cache Value"]
            )
        )
    }
}

```
