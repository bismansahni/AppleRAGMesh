//
//  VisualEffectView.swift
//  RAGMesh
//
//  Created by Bisman Sahni on 7/25/25.
//




import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var opacity: CGFloat = 0.85

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.layer?.backgroundColor = NSColor.black.withAlphaComponent(opacity).cgColor
    }
}
