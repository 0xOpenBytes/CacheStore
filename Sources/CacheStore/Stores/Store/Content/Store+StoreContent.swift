import c

public extension Store {
    /// Create a StoreContent for the provided content type
    func content<Content: StoreContent>(
        using contentType: Content.Type = Content.self
    ) -> Content where Content.Key == Key {
        contentType.init(
            store: actionlessScope(
                keyTransformation: c.transformer(from: { $0 }, to: { $0 }),
                dependencyTransformation: { _ in () }
            )
        )
    }
}
