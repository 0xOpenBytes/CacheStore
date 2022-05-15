public protocol ActionHandling {
    associatedtype Action
    
    func handle(action: Action)
}

public typealias StateActionHandling<Key: Hashable, Action, Dependency> = (inout CacheStore<Key>, Action, Dependency) -> Void
