//
//  MessageType.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import Foundation

public enum MessageType: String {
    case initialFileEmbedding = "initialfileembedding"
    case initialEmbeddingResult = "initialembeddingresult"
    case queryEmbedding = "queryembedding"
    case retrievalResult = "retrievalresult"
}
