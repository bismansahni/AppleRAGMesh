//
//  PeerSessionDelegate.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import Foundation
import MultipeerConnectivity

public protocol PeerSessionDelegate: AnyObject {
    func didReceiveMessage(_ message: [String: Any], from peer: MCPeerID)
    func didChangeState(peer: MCPeerID, state: MCSessionState)
}

public final class PeerSessionManager: NSObject {
    private let serviceType = "rag-service"
    private let peerID: MCPeerID
    public let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    public weak var delegate: PeerSessionDelegate?

    public init(displayName: String, role: Role) {
        self.peerID = MCPeerID(displayName: displayName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        super.init()

        session.delegate = self

        switch role {
        case .advertiser:
            advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
            advertiser?.delegate = self
            advertiser?.startAdvertisingPeer()
        case .browser:
            browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
            browser?.delegate = self
            browser?.startBrowsingForPeers()
        }
    }

    public func send(_ message: [String: Any]) {
        guard !session.connectedPeers.isEmpty else {
            print("⚠️ No connected peers to send message")
            return
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("❌ Failed to send message: \(error)")
        }
    }

    public enum Role {
        case advertiser, browser
    }
}

extension PeerSessionManager: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        delegate?.didChangeState(peer: peerID, state: state)
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                delegate?.didReceiveMessage(json, from: peerID)
            }
        } catch {
            print("❌ Failed to decode received data: \(error)")
        }
    }

    // Unused
    public func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    public func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    public func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

extension PeerSessionManager: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext _: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension PeerSessionManager: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo _: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("⚠️ Lost peer: \(peerID.displayName)")
    }
}
