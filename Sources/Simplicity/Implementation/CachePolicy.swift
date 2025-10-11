//
//  CachePolicy.swift
//  Simplicity
//
//  Created by Brent Mifsud on 2025-10-10.
//

public nonisolated enum CachePolicy: Sendable {
    case useProtocolCachePolicy
    case reloadIgnoringLocalCacheData
    case reloadIgnoringLocalAndRemoteCacheData
    case returnCacheDataElseLoad
    case returnCacheDataDontLoad
    case reloadRevalidatingCacheData
}
