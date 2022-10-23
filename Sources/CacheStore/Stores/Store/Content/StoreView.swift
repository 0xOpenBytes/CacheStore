import SwiftUI

/// SwiftUI View that uses a Store and StoreContent
public protocol StoreView: View {
    /// Key for the Store
    associatedtype Key: Hashable
    /// Action for the Store
    associatedtype Action
    /// Dependency for the Store
    associatedtype Dependency
    /// The content the View cares about and uses
    associatedtype Content: StoreContent
    /// The View created from the current Content
    associatedtype ContentView: View

    /// An `ObservableObject` that uses actions to modify the state which is a `CacheStore`
    var store: Store<Key, Action, Dependency> { get set }

    init(store: Store<Key, Action, Dependency>)

    /// Create the body view with the current Content of the Store. View's body property is defaulted to using this function.
    /// -   Parameters:
    ///     - content: The content a StoreView uses when creating SwiftUI views
    func body(content: Content) -> ContentView
}

public extension StoreView where Content.Key == Key {
    var body: some View {
        body(content: store.content())
    }
}
