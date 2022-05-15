class ScopedStore<
    Key: Hashable, ScopedKey: Hashable,
    Action, ScopedAction,
    Dependency, ScopedDependency
>: Store<ScopedKey, ScopedAction, ScopedDependency> {
    weak var parentStore: Store<Key, Action, Dependency>?
    
    required init(
        initialValues: [ScopedKey : Any],
        actionHandler: @escaping StateActionHandling<ScopedKey, ScopedAction, ScopedDependency>,
        dependency: ScopedDependency
    ) {
        super.init(initialValues: initialValues, actionHandler: actionHandler, dependency: dependency)
    }
}

