//
//  MessageHandlingDelegate.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import Foundation
import MultipeerConnectivity

public protocol MessageHandlingDelegate: AnyObject {
    func handleInitialFileEmbedding(_ data: [String: Any], from peer: MCPeerID)
    func handleInitialEmbeddingResult(_ data: [String: Any], from peer: MCPeerID)
    func handleQueryEmbedding(_ data: [String: Any], from peer: MCPeerID)
    func handleRetrievalResult(_ data: [String: Any], from peer: MCPeerID)
}

public class MessageHandler {
    public weak var delegate: MessageHandlingDelegate?

    public init(delegate: MessageHandlingDelegate) {
        self.delegate = delegate
    }

    public func handle(_ message: [String: Any], from peer: MCPeerID) {
        guard let typeString = message["type"] as? String,
              let type = MessageType(rawValue: typeString) else {
            print("❌ Unknown or missing message type: \(message["type"] ?? "nil")")
            return
        }

        switch type {
        case .initialFileEmbedding:
            delegate?.handleInitialFileEmbedding(message, from: peer)
        case .initialEmbeddingResult:
            delegate?.handleInitialEmbeddingResult(message, from: peer)
        case .queryEmbedding:
            delegate?.handleQueryEmbedding(message, from: peer)
        case .retrievalResult:
            delegate?.handleRetrievalResult(message, from: peer)
        }
    }
}
