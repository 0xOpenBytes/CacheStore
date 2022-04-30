import c
import SwiftUI

public class CacheStore<CacheKey: Hashable>: ObservableObject, Cacheable {
    private var lock: NSLock
    @Published private var cache: [CacheKey: Any]
    
    required public init(initialValues: [CacheKey: Any]) {
        lock = NSLock()
        cache = initialValues
    }
    
    public func get<Value>(_ key: CacheKey) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key] as? Value
    }
    
    public func resolve<Value>(_ key: CacheKey) -> Value { get(key)! }
    
    public func set<Value>(value: Value, forKey key: CacheKey) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.set(value: value, forKey: key)
            }
            return
        }
        
        lock.lock()
        cache[key] = value
        lock.unlock()
    }
}
