//
//  EmbeddedChunk.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//




import Foundation

public struct EmbeddedChunk: Codable {
    public let chunkIndex: Int
    public let text: String
    public let embedding: [Float]
}

public struct ChunkRecord {
    public let id: Int64?
    public let file: String
    public let chunkIndex: Int
    public let text: String
    public let embedding: [Float]
    public let device: String
}
