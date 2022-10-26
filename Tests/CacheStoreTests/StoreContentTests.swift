//
//  StoreContentTests.swift
//  
//
//  Created by Leif on 10/24/22.
//

import XCTest
@testable import CacheStore

final class StoreContentTests: XCTestCase {
    func testBasicContent() throws {
        enum Key {
            case text
        }

        enum Action {
            case updateText(String)
        }

        let store = Store<Key, Action, Void>(
            initialValues: [:],
            actionHandler: StoreActionHandler<Key, Action, ()> { cacheStore, action, _ in
                switch action {
                case let .updateText(text):
                    cacheStore.set(value: text, forKey: .text)
                    return .none
                }
            }
        )

        struct ViewContent: StoreContent {
            let text: String

            init(store: Store<Key, Void, Void>) {
                text = store.get(.text) ?? "Hello, World"
            }
        }

        XCTAssertEqual(store.content(using: ViewContent.self).text, "Hello, World")

        store.handle(action: .updateText("Updated!"))

        XCTAssertEqual(store.content(using: ViewContent.self).text, "Updated!")
    }
}
