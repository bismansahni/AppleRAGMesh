//
//  LogManager.swift
//  MESH_PROJECT
//
//  Created by Bisman Sahni on 7/25/25.
//


import Foundation

public class LogManager {
    public static let shared = LogManager()
    private init() {}

    public func append(_ message: String) {
        print("[LOG] \(message)")
    }
}
