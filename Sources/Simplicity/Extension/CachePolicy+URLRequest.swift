//
//  CachePolicy+URLRequest.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

#if canImport(FoundationNetworking)
import Foundation
public import FoundationNetworking
#else
public import Foundation
#endif

public extension CachePolicy {
    var urlRequestCachePolicy: URLRequest.CachePolicy {
        switch self {
        case .useProtocolCachePolicy:
            return .useProtocolCachePolicy
        case .reloadIgnoringLocalCacheData:
            return .reloadIgnoringLocalCacheData
        case .reloadIgnoringLocalAndRemoteCacheData:
            return .reloadIgnoringLocalAndRemoteCacheData
        case .returnCacheDataElseLoad:
            return .returnCacheDataElseLoad
        case .returnCacheDataDontLoad:
            return .returnCacheDataDontLoad
        case .reloadRevalidatingCacheData:
            return .reloadRevalidatingCacheData
        }
    }
}
