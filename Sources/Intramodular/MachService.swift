//
// Copyright (c) Vatsal Manot
//

#if os(macOS)

import Foundation
import ServiceManagement
import Swift

/// This is what the XPC service (aka **NOT** the main/sandboxed app) will run in its `main.swift` file.
public class MachService<RemoteObject, ExportedObject: MachServiceServer>: NSObject, MachServiceServer, NSXPCListenerDelegate {
    public let machServiceName: String
    public let remoteObjectProtocol: Protocol
    public let exportedObjectProtocol: Protocol
    
    private let authorizer = MachServiceAuthorizer(authorizationRights: [])
    private let listener: NSXPCListener
    
    private var connections = [NSXPCConnection]()
    private var shouldQuit = false
    private var shouldQuitCheckInterval = 1.0
    
    public var bundleVersionString: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    public init(
        machServiceName: String,
        remoteObjectProtocol: Protocol,
        exportedObjectProtocol: Protocol
    ) {
        self.machServiceName = machServiceName
        self.remoteObjectProtocol = remoteObjectProtocol
        self.exportedObjectProtocol = exportedObjectProtocol
        self.listener = NSXPCListener(machServiceName: machServiceName)
        
        super.init()
        
        listener.delegate = self
    }
    
    public func run() {
        self.listener.resume()
        
        while !shouldQuit {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: self.shouldQuitCheckInterval))
        }
    }
    
    // MARK: - NSXPCListenerDelegate
    
    public func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        guard isValid(connection: connection) else {
            return false
        }
        
        connection.remoteObjectInterface = NSXPCInterface(with: remoteObjectProtocol)
        connection.exportedInterface = NSXPCInterface(with: exportedObjectProtocol)
        connection.exportedObject = self
        
        connection.invalidationHandler = { [weak self] in
            guard let `self` = self else {
                return
            }
            
            if let connectionIndex = self.connections.firstIndex(of: connection) {
                self.connections.remove(at: connectionIndex)
            }
            
            if self.connections.isEmpty {
                self.shouldQuit = true
            }
        }
        
        self.connections.append(connection)
        
        connection.resume()
        
        return true
    }
    
    func getVersion(completion: (String) -> Void) {
        completion(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0")
    }
    
    private func isValid(
        connection: NSXPCConnection
    ) -> Bool {
        do {
            return try CodesignCheck.codeSigningMatches(pid: connection.processIdentifier)
        } catch {
            NSLog("Code signing check failed with error: \(error)")
            return false
        }
    }
    
    private func verify(
        authorizationData data: NSData?,
        for command: Selector
    ) throws {
        try authorizer.verify(authorizationData: data, for: command)
    }
    
    private func connection() -> NSXPCConnection? {
        return self.connections.last
    }
}

#endif
