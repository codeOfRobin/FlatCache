//
//  FlatCache.swift
//  Freetime
//
//  Created by Ryan Nystrom on 10/20/17.
//  Copyright © 2017 Ryan Nystrom. All rights reserved.
//

import Foundation

public struct FlatCacheKey: Equatable, Hashable {
    public let typeName: String
    public let id: String
}

public protocol FlatCacheStorage {
	func set<T: Cachable>(value: T) throws
	func get<T: Cachable>(key: FlatCacheKey) -> T?
	func clear() throws
}

public protocol Identifiable {
    var id: String { get }
}

public protocol DataConvertible {
	func toData() throws -> Data
	static func create(from data: Data) throws -> Self
}

public protocol Cachable: Identifiable & DataConvertible { }

public extension Cachable {
    static var typeName: String {
        return String(describing: self)
    }

    var flatCacheKey: FlatCacheKey {
        return FlatCacheKey(typeName: Self.typeName, id: id)
    }
}

public protocol FlatCacheListener: AnyObject {
    func flatCacheDidUpdate(cache: FlatCache, update: FlatCache.Update)
}

public final class FlatCache {

    public enum Update {
        case item(Any)
        case list([Any])
        case clear
    }

	private let underlyingStorage: FlatCacheStorage
//    private var storage: [FlatCacheKey: Any] = [:]
    private let queue = DispatchQueue(
        label: "com.freetime.FlatCache.queue",
        qos: .userInitiated,
        attributes: .concurrent
    )

    private var listeners: [FlatCacheKey: NSHashTable<AnyObject>] = [:]

	public init(storage: FlatCacheStorage) {
		self.underlyingStorage = storage
	}

    public func add<T: Cachable>(listener: FlatCacheListener, value: T) {
        assert(Thread.isMainThread)

        let key = value.flatCacheKey
        let table: NSHashTable<AnyObject>
        if let existing = listeners[key] {
            table = existing
        } else {
            table = NSHashTable.weakObjects()
        }
        table.add(listener)
        listeners[key] = table
    }

    public func set<T: Cachable>(value: T) throws {
        assert(Thread.isMainThread)

        let key = value.flatCacheKey
//        storage[key] = value
		try underlyingStorage.set(value: value)

        enumerateListeners(key: key) { listener in
            listener.flatCacheDidUpdate(cache: self, update: .item(value))
        }
    }

    private func enumerateListeners(key: FlatCacheKey, block: (FlatCacheListener) -> ()) {
        assert(Thread.isMainThread)

        if let table = listeners[key] {
            for object in table.objectEnumerator() {
                if let listener = object as? FlatCacheListener {
                    block(listener)
                }
            }
        }
    }

    public func set<T: Cachable>(values: [T]) throws {
        assert(Thread.isMainThread)

        var listenerHashToValuesMap = [Int: [T]]()
        var listenerHashToListenerMap = [Int: FlatCacheListener]()

        for value in values {
            let key = value.flatCacheKey
            try underlyingStorage.set(value: value)

            enumerateListeners(key: key, block: { listener in
                let hash = ObjectIdentifier(listener).hashValue
                if var arr = listenerHashToValuesMap[hash] {
                    arr.append(value)
                    listenerHashToValuesMap[hash] = arr
                } else {
                    listenerHashToValuesMap[hash] = [value]
                }
                listenerHashToListenerMap[hash] = listener
            })
        }

        for (hash, arr) in listenerHashToValuesMap {
            guard let listener = listenerHashToListenerMap[hash] else { continue }
            if arr.count == 1, let first = arr.first {
                listener.flatCacheDidUpdate(cache: self, update: .item(first))
            } else {
                listener.flatCacheDidUpdate(cache: self, update: .list(arr))
            }
        }
    }

    public func get<T: Cachable>(id: String) -> T? {
        assert(Thread.isMainThread)

        let key = FlatCacheKey(typeName: T.typeName, id: id)
		return underlyingStorage.get(key: key)
    }

	public func clear() throws {
        assert(Thread.isMainThread)
        
        try underlyingStorage.clear()

        for key in listeners.keys {
            enumerateListeners(key: key) { listener in
                listener.flatCacheDidUpdate(cache: self, update: .clear)
            }
        }
    }

}

