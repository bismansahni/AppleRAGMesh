//
//  ChunkUtils.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import Foundation

public extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
