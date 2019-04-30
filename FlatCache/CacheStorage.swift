//
//  CacheStorage.swift
//  FlatCache
//
//  Created by Robin Malhotra on 28/04/19.
//  Copyright © 2019 Ryan Nystrom. All rights reserved.
//

import Foundation
import PINCache

public class PINCacheFlatCacheStorage: FlatCacheStorage {

	var pinCaches: [String: PINCache] = [:]
	let rootPath: String?

	init(rootPath: String? = nil) {
		self.rootPath = rootPath
	}

	public func set<T>(value: T) throws where T : Cachable {

		let pinCache: PINCache
		if let cache = pinCaches[value.flatCacheKey.typeName] {
			pinCache = cache
		} else {
			let name = value.flatCacheKey.typeName
			pinCache = rootPath.map{ PINCache(name: name, rootPath: $0) } ?? PINCache(name: name)
			pinCaches[value.flatCacheKey.typeName] = pinCache
		}
		// as NSData feels * so wrong * but I guess it works
		// `Data` isn't NSCodingCompliant, but NSData is 🤯
		pinCache.setObject(try value.toData() as NSData, forKey: value.id)
	}

	public func get<T>(key: FlatCacheKey) -> T? where T : Cachable {
		if let data = pinCaches[key.typeName]?.object(forKey: key.id) as? Data {
			return try? T.create(from: data)
		} else {
			return nil
		}
	}

	public func clear() throws {
		pinCaches.forEach{ $0.value.removeAllObjects() }
	}

}
