import SwiftUI

public protocol StoreView: View {
    associatedtype Key: Hashable
    associatedtype Action
    associatedtype Dependency
    associatedtype Content: StoreContent
    
    var store: Store<Key, Action, Dependency> { get set }
    var content: Content { get }
    
    init(store: Store<Key, Action, Dependency>)
}

public extension StoreView where Content.Key == Key {
    var content: Content { store.content() }
}
