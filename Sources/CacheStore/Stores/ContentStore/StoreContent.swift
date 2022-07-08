import c

public protocol StoreContent {
    associatedtype Key: Hashable
    
    init(store: Store<Key, Void, Void>)
}
