class ScopedStore<
    Key: Hashable, ScopedKey: Hashable,
    Action, ScopedAction,
    Dependency, ScopedDependency
>: Store<ScopedKey, ScopedAction, ScopedDependency> {
    weak var parentStore: Store<Key, Action, Dependency>?
    
    required init(
        initialValues: [ScopedKey : Any],
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>,
        dependency: ScopedDependency
    ) {
        super.init(initialValues: initialValues, actionHandler: actionHandler, dependency: dependency)
    }
    
    /// An identifier of the Store and CacheStore
    override var debugIdentifier: String {
        guard let parentStore = parentStore else {
            return super.debugIdentifier
        }
        
        var storeDescription: String = "\(self)".replacingOccurrences(of: "CacheStore.", with: "")
        
        guard let index = storeDescription.firstIndex(of: "<") else {
            return "(Store: \(storeDescription), Parent: \(parentStore.debugIdentifier))"
        }
        
        storeDescription = storeDescription[..<index].description // "ScopedStore"
        storeDescription += "<\(ScopedKey.self), \(ScopedAction.self), \(ScopedDependency.self)>"
        
        return "(Store: \(storeDescription), Parent: \(parentStore.debugIdentifier))"
    }
}

