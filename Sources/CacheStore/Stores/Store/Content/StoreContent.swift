/// The content a StoreView uses when creating SwiftUI views
public protocol StoreContent {
    associatedtype Key: Hashable
    
    /// Creates the content from an actionless store that has a Void dependency
    init(store: Store<Key, Void, Void>)
}
