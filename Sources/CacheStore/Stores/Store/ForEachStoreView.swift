//
//  ForEachStoreView.swift
//  
//
//  Created by Leif on 11/9/22.
//

import SwiftUI

struct ForEachStoreView<
    Key: Hashable, Action, Dependency,
    Value: Hashable, ScopedKey: Hashable, ScopedAction, ScopedDependency,
    NoContentView: View, ContentView: View
>: View {
    @ObservedObject var store: Store<Key, Action, Dependency>

    var key: Key
    var type: Value.Type
    var scopedKey: ScopedKey
    var actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>
    var dependencyTransformation: (Dependency) -> ScopedDependency
    var defaultCache: [ScopedKey: Any]
    var actionTransformation: (ScopedAction?) -> Action?
    var noContentView: NoContentView
    var content: (Store<ScopedKey, ScopedAction, ScopedDependency>) -> ContentView

    init(
        store: Store<Key, Action, Dependency>,
        key: Key,
        as type: Value.Type,
        toScopedKey scopedKey: ScopedKey,
        actionHandler: StoreActionHandler<ScopedKey, ScopedAction, ScopedDependency>,
        dependencyTransformation: @escaping (Dependency) -> ScopedDependency,
        defaultCache: [ScopedKey: Any] = [:],
        actionTransformation: @escaping (ScopedAction?) -> Action? = { _ in nil },
        noContentView: NoContentView,
        content: @escaping (Store<ScopedKey, ScopedAction, ScopedDependency>) -> ContentView
    ) {
        self.store = store
        self.key = key
        self.type = type
        self.scopedKey = scopedKey
        self.actionHandler = actionHandler
        self.dependencyTransformation = dependencyTransformation
        self.defaultCache = defaultCache
        self.actionTransformation = actionTransformation
        self.noContentView = noContentView
        self.content = content
    }

    var body: some View {
        if
            let data: [Value] = store.get(key),
            data.isEmpty == false
        {
            ForEach(0 ..< data.count, id: \.self) { datumIndex in
                let value = data[datumIndex]

                content(
                    store.scope(
                        keyValueTransformation: (
                            from: { (keyValue: (Key, [Value]?)?) in
                                (scopedKey, value)
                            },
                            to: { (scopedKeyValue: (ScopedKey, Value?)?) in
                                var mutatedData = data

                                if let value = scopedKeyValue?.1 {
                                    mutatedData[datumIndex] = value
                                }

                                return (key, mutatedData)
                            }
                        ),
                        actionHandler: actionHandler,
                        dependencyTransformation: dependencyTransformation,
                        defaultCache: defaultCache,
                        actionTransformation: actionTransformation
                    )
                )
            }
        } else {
            noContentView
        }
    }
}
