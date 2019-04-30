//
//  FlatCacheTests.swift
//  FreetimeTests
//
//  Created by Ryan Nystrom on 10/21/17.
//  Copyright © 2017 Ryan Nystrom. All rights reserved.
//

import XCTest
@testable import FlatCache

let cacheEncoder: JSONEncoder = {
	let encoder = JSONEncoder()
	return encoder
}()

let cacheDecoder: JSONDecoder = {
	let decoder = JSONDecoder()
	return decoder
}()

extension Cachable where Self: Codable {
	func toData() throws -> Data {
		return try cacheEncoder.encode(self)
	}

	static func create(from data: Data) throws -> Self {
		return try cacheDecoder.decode(Self.self, from: data)
	}

}


struct CacheModel: Cachable, Codable {
    let id: String
    let value: String
}

class CacheModelListener: FlatCacheListener {
    var receivedItemQueue = [CacheModel]()
    var receivedListQueue = [[CacheModel]]()
    var hasCleared = false

    func flatCacheDidUpdate(cache: FlatCache, update: FlatCache.Update) {
        switch update {
        case .item(let item): receivedItemQueue.append(item as! CacheModel)
        case .list(let list): receivedListQueue.append(list as! [CacheModel])
        case .clear: hasCleared = true
        }
    }
}

struct OtherCacheModel: Cachable, Codable {
    let id: String
}

class FlatCacheTests: XCTestCase {
    
    func test_whenSettingSingleModel_thatResultExistsForType() throws {
		let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        try cache.set(value: CacheModel(id: "1", value: ""))
        XCTAssertNotNil(cache.get(id: "1") as CacheModel?)
    }

    func test_whenSettingSingleModel_withUupdatedModel_thatResultMostRecent() throws {
		let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        try cache.set(value: CacheModel(id: "1", value: "foo"))
        try cache.set(value: CacheModel(id: "1", value: "bar"))
        XCTAssertEqual((cache.get(id: "1") as CacheModel?)?.value, "bar")
    }

    func test_whenSettingSingleModel_thatNoResultExsistForUnsetId() throws {
		let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        try cache.set(value: CacheModel(id: "1", value: ""))
        XCTAssertNil(cache.get(id: "2") as CacheModel?)
    }

    func test_whenSettingSingleModel_thatNoResultExistsForOtherType() throws {
		let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        try cache.set(value: CacheModel(id: "1", value: ""))
        XCTAssertNil(cache.get(id: "1") as OtherCacheModel?)
    }

    func test_whenSettingManyModels_thatResultsExistForType() throws {
		let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        try cache.set(values: [
            CacheModel(id: "1", value: ""),
            CacheModel(id: "2", value: ""),
            CacheModel(id: "3", value: ""),
            ])
        XCTAssertNotNil(cache.get(id: "1") as CacheModel?)
        XCTAssertNotNil(cache.get(id: "2") as CacheModel?)
        XCTAssertNotNil(cache.get(id: "3") as CacheModel?)
    }

    func test_whenSettingSingleModel_withListeners_whenMultipleUpdates_thatCorrectListenerReceivesUpdate() throws {
        let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        let l1 = CacheModelListener()
        let l2 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "")
        let m2 = CacheModel(id: "2", value: "")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l2, value: m2)
        try cache.set(value: m1)
        try cache.set(value: CacheModel(id: "1", value: "foo"))
        XCTAssertEqual(l1.receivedItemQueue.count, 2)
        XCTAssertEqual(l1.receivedListQueue.count, 0)
        XCTAssertEqual(l1.receivedItemQueue.last?.id, "1")
        XCTAssertEqual(l1.receivedItemQueue.last?.value, "foo")
        XCTAssertEqual(l2.receivedItemQueue.count, 0)
        XCTAssertEqual(l2.receivedListQueue.count, 0)
    }

    func test_whenSettingMultipleModels_withListenerOnAll_whenMultipleUpdates_thatListenerReceivesUpdate() throws {
		let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        let l1 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "foo")
        let m2 = CacheModel(id: "2", value: "bar")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l1, value: m2)
        try cache.set(values: [m1, m2])
        XCTAssertEqual(l1.receivedItemQueue.count, 0)
        XCTAssertEqual(l1.receivedListQueue.count, 1)
        XCTAssertEqual(l1.receivedListQueue.last?.count, 2)
        XCTAssertEqual(l1.receivedListQueue.last?.first?.value, "foo")
        XCTAssertEqual(l1.receivedListQueue.last?.last?.value, "bar")
    }

    func test_whenSettingTwoModels_withListenerForEach_thatListenersReceiveItemUpdates() throws {
        let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        let l1 = CacheModelListener()
        let l2 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "foo")
        let m2 = CacheModel(id: "2", value: "bar")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l2, value: m2)
        try cache.set(values: [m1, m2])
        XCTAssertEqual(l1.receivedItemQueue.count, 1)
        XCTAssertEqual(l1.receivedListQueue.count, 0)
        XCTAssertEqual(l1.receivedItemQueue.last?.value, "foo")
        XCTAssertEqual(l2.receivedItemQueue.count, 1)
        XCTAssertEqual(l2.receivedListQueue.count, 0)
        XCTAssertEqual(l2.receivedItemQueue.last?.value, "bar")
    }

    func test_whenClearingCache() throws {
        let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        try cache.set(value: CacheModel(id: "1", value: ""))
        try cache.clear()
        XCTAssertNil(cache.get(id: "1") as CacheModel?)
    }

    func test_whenClearing_withListenerForEach_thatListenersReceiveClearUpdates() throws {
        let cache = FlatCache(storage: PINCacheFlatCacheStorage(rootPath: "\(#function)"))
        let l1 = CacheModelListener()
        let l2 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "foo")
        let m2 = CacheModel(id: "2", value: "bar")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l2, value: m2)
        try cache.set(values: [m1, m2])

        XCTAssertFalse(l1.hasCleared)
        XCTAssertFalse(l2.hasCleared)

        try cache.clear()

        XCTAssertTrue(l1.hasCleared)
        XCTAssertTrue(l2.hasCleared)
    }
    
}
