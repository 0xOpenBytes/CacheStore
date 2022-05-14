public protocol ActionHandling {
    associatedtype Action
    
    func handle(action: Action)
}

public typealias StateActionHandling<Key: Hashable, Action, XYZ> = (inout CacheStore<Key>, Action, XYZ) -> Void
