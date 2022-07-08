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
    
    /// An `ObservableObject` that uses actions to modify the state which is a `CacheStore`
    var store: Store<Key, Action, Dependency> { get set }
    /// The content a StoreView uses when creating SwiftUI views
    var content: Content { get }
    
    init(store: Store<Key, Action, Dependency>)
}

public extension StoreView where Content.Key == Key {
    var content: Content { store.content() }
}
