# CacheStore

*SwiftUI Observable Cache*

## What is `CacheStore`?

`CacheStore` is a SwiftUI framework to help with state. Define keyed values that you can share locally or globally in your projects. `CacheStore` uses [`c`](https://github.com/0xOpenBytes/c), which a simple composition framework. [`c`](https://github.com/0xOpenBytes/c) has the ability to create transformations that are either unidirectional or bidirectional. There is also a cache that values can be set and resolved, which is used in `CacheStore`.

## Basic Example

Here is a simple application that has two files, an `App` file and `ContentView` file. The `App` contains the `StateObject` `CacheStore`. It then adds the `CacheStore` to the global cache using [`c`](https://github.com/0xOpenBytes/c). `ContentView` can then resolve the cache as an `ObservableObject` which can read or write to the cache. The cache can be injected into the `ContentView` directly, see `ContentView_Previews`, or indirectly, see `ContentView`.

### DemoApp
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
