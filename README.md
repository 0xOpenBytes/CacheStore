# CacheStore

*SwiftUI State Management*

## What is `CacheStore`?

`CacheStore` is a SwiftUI State Management framework to help with state. Define keyed values that you can share locally or globally in your projects. `CacheStore` uses [`c`](https://github.com/0xOpenBytes/c), which a simple composition framework. [`c`](https://github.com/0xOpenBytes/c) has the ability to create transformations that are either unidirectional or bidirectional. There is also a cache that values can be set and resolved, which is used in `CacheStore`.

### CacheStore Basic Idea

A `[AnyHashable: Any]` can be used as the single source of truth for an app. Scoping can be done by limiting the known keys. Modification to the scoped value or parent value should be reflected throughout the app.

## Objects 
- `CacheStore`: An object that needs defined Keys to get and set values.
- `Store`: An object that needs defined Keys, Actions, and Dependencies. (Preferred)
    - `TestStore`: A testable wrapper around `Store` to make it easy to write XCTestCases

### Store

A `Store` is an object that you send actions to and read state from. Stores use a `CacheStore` to manage state behind the scenes. All state changes must be defined in a `StoreActionHandler` where the state gets modified depending on an action.

### TestStore

When creating tests you should use `TestStore` to send and receive actions while making expectations. If any expectation is false it will be reported in a `XCTestCase`. If there are any effects left at the end of the test, there will be a failure as all effects must be completed and all resulting actions handled. `TestStore` uses a FIFO (first in first out) queue to manage the effects.

## Basic Usage

<details> 
  <summary>Store Example</summary> 

```swift 
import CacheStore
import SwiftUI

struct Post: Codable, Hashable {
    var id: Int
    var userId: Int
    var title: String
    var body: String
}

enum StoreKey {
    case url
    case posts
    case isLoading
}

enum Action {
    case fetchPosts
    case postsResponse(Result<[Post], Error>)
}

extension String: Error { }

struct Dependency {
    var fetchPosts: (URL) async -> Result<[Post], Error>
}

extension Dependency {
    static var mock: Dependency {
        Dependency(
            fetchPosts: { _ in
                sleep(1)
                return .success([Post(id: 1, userId: 1, title: "Mock", body: "Post")])
            }
        )
    }
    
    static var live: Dependency {
        Dependency { url in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return .success(try JSONDecoder().decode([Post].self, from: data))
            } catch {
                return .failure(error)
            }
        }
    }
}

let actionHandler = StoreActionHandler<StoreKey, Action, Dependency> { cacheStore, action, dependency in
    switch action {
    case .fetchPosts:
        struct FetchPostsID: Hashable { }
        
        guard let url = cacheStore.get(.url, as: URL.self) else {
            return ActionEffect(.postsResponse(.failure("Key `.url` was not a URL")))
        }
        
        cacheStore.set(value: true, forKey: .isLoading)
        
        return ActionEffect(id: FetchPostsID()) {
            .postsResponse(await dependency.fetchPosts(url))
        }
        
    case let .postsResponse(.success(posts)):
        cacheStore.set(value: false, forKey: .isLoading)
        cacheStore.set(value: posts, forKey: .posts)
        
    case let .postsResponse(.failure(error)):
        cacheStore.set(value: false, forKey: .isLoading)
    }
    
    return .none
}

struct ContentView: View {
    @ObservedObject var store: Store<StoreKey, Action, Dependency> = .init(
        initialValues: [
            .url: URL(string: "https://jsonplaceholder.typicode.com/posts") as Any
        ],
        actionHandler: actionHandler,
        dependency: .live
    )
        .debug
    
    private var isLoading: Bool {
        store.get(.isLoading, as: Bool.self) ?? true
    }
    
    var body: some View {
        if
            !isLoading,
            let posts = store.get(.posts, as: [Post].self)
        {
            List(posts, id: \.self) { post in
                Text(post.title)
            }
        } else {
            ProgressView()
                .onAppear {
                    store.handle(action: .fetchPosts)
                }
        }
    }
}
```

</details>

<details> 
  <summary>Testing</summary> 

```swift
import CacheStore
import XCTest
@testable import CacheStoreDemo

class CacheStoreDemoTests: XCTestCase {
    override func setUp() {
        TestStoreFailure.handler = XCTFail
    }
    
    func testExample_success() throws {
        let store = TestStore(
            initialValues: [
                .url: URL(string: "https://jsonplaceholder.typicode.com/posts") as Any
            ],
            actionHandler: actionHandler,
            dependency: .mock
        )
        
        store.send(.fetchPosts) { cacheStore in
            cacheStore.set(value: true, forKey: .isLoading)
        }
        store.send(.fetchPosts) { cacheStore in
            cacheStore.set(value: true, forKey: .isLoading)
        }
        
        let expectedPosts: [Post] = [Post(id: 1, userId: 1, title: "Mock", body: "Post")]
        
        store.receive(.postsResponse(.success(expectedPosts))) { cacheStore in
            cacheStore.set(value: false, forKey: .isLoading)
            cacheStore.set(value: expectedPosts, forKey: .posts)
        }
    }
    
    func testExample_failure() throws {
        let store = TestStore(
            initialValues: [
                :
            ],
            actionHandler: actionHandler,
            dependency: .mock
        )
        
        store.send(.fetchPosts, expecting: { _ in })
        
        store.receive(.postsResponse(.failure("Key `.url` was not a URL"))) { cacheStore in
            cacheStore.set(value: false, forKey: .isLoading)
        }
    }
}
```

</details>

***

## Acknowledgement of Dependencies
- [pointfreeco/swift-custom-dump](https://github.com/pointfreeco/swift-custom-dump)


## Inspiration
- [pointfreeco/swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)
