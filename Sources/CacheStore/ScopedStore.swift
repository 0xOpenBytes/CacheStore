import c

class ScopedStore<
    Key: Hashable, ScopedKey: Hashable,
    Action, ScopedAction,
    XYZ, ScopedXYZ
>: Store<ScopedKey, ScopedAction, ScopedXYZ> {
    weak var parentStore: Store<Key, Action, XYZ>?
    
    required init(
        initialValues: [ScopedKey : Any],
        actionHandler: @escaping StateActionHandling<ScopedKey, ScopedAction, ScopedXYZ>,
        xyz: ScopedXYZ
    ) {
        super.init(initialValues: initialValues, actionHandler: actionHandler, xyz: xyz)
    }
}

