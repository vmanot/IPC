//
// Copyright (c) Vatsal Manot
//

import Foundation
#if os(macOS) || targetEnvironment(macCatalyst)
import ServiceManagement
#endif
import Swift

open class MachServiceConnection<
    RemoteObject: MachServiceClient,
    ExportedObject: MachServiceServer
>: MachServiceClient {
    public enum Error: Swift.Error {
        case unsupportedPlatform
    }
    
    public let machServiceName: String
    public let remoteObjectProtocol: Protocol
    public let exportedObjectProtocol: Protocol
    public let connectionOptions: NSXPCConnection.Options
    
    private var activeConnection: NSXPCConnection?
    
    public init(
        machServiceName: String,
        remoteObjectProtocol: Protocol,
        exportedObjectProtocol: Protocol,
        connectionOptions: NSXPCConnection.Options = .privileged
    ) {
        self.machServiceName = machServiceName
        self.remoteObjectProtocol = remoteObjectProtocol
        self.exportedObjectProtocol = exportedObjectProtocol
        self.connectionOptions = connectionOptions
    }
    
    func exportObject(_ onError: @escaping (Swift.Error) -> Void) -> ExportedObject? {
        do {
            return try self.connection().remoteObjectProxyWithErrorHandler(onError) as? ExportedObject
        } catch {
            onError(error)
            
            return nil
        }
    }
    
    func connection() throws -> NSXPCConnection {
        #if os(macOS)
        if let activeConnection = activeConnection {
            return activeConnection
        }
        
        let connection = NSXPCConnection(machServiceName: machServiceName, options: .privileged)
        
        defer {
            activeConnection = connection
        }
        
        connection.exportedInterface = NSXPCInterface(with: remoteObjectProtocol)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: exportedObjectProtocol)
        
        connection.invalidationHandler = { [weak self] in
            self?.activeConnection?.invalidationHandler = nil
            
            OperationQueue.main.addOperation {
                self?.activeConnection = nil
            }
        }
        
        connection.resume()
        
        return connection
        #else
        throw Error.unsupportedPlatform
        #endif
    }
}
