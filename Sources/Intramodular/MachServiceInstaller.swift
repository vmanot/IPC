//
// Copyright (c) Vatsal Manot
//

import Foundation
#if os(macOS) || targetEnvironment(macCatalyst)
import ServiceManagement
#endif
import Swift

public class MachServiceInstaller {
    public enum Error: Swift.Error {
        case unsupportedPlatform
    }
    
    public let machServiceName: String
    
    public init(machServiceName: String) {
        self.machServiceName = machServiceName
    }
    
    public func install() throws {
        #if os(macOS)
        var error: Unmanaged<CFError>? = nil
        
        let blessed = SMJobBless(
            kSMDomainSystemLaunchd,
            machServiceName as CFString,
            try getAuthorization(),
            &error
        )
        
        if !blessed {
            throw error!.takeRetainedValue() as Swift.Error
        }
        #else
        throw Error.unsupportedPlatform
        #endif
    }
    
    #if os(macOS) || targetEnvironment(macCatalyst)
    private func getAuthorization() throws -> AuthorizationRef {
        try kSMRightBlessPrivilegedHelper.withCString { authorizationItenName in
            var authorizationRef: AuthorizationRef?
            
            var authorizationItem = AuthorizationItem(
                name: authorizationItenName,
                valueLength: 0,
                value: UnsafeMutableRawPointer(bitPattern: 0),
                flags: 0
            )
            
            return try withUnsafeMutablePointer(to: &authorizationItem) { authorizationItem in
                var authorizationRights = AuthorizationRights(
                    count: 1,
                    items: authorizationItem
                )
                
                let authorizationFlags: AuthorizationFlags = [
                    [],
                    .extendRights,
                    .interactionAllowed,
                    .preAuthorize
                ]
                
                let status = AuthorizationCreate(
                    &authorizationRights,
                    nil,
                    authorizationFlags,
                    &authorizationRef
                )
                
                if status != errAuthorizationSuccess {
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
                }
                
                return authorizationRef!
            }
        }
    }
    #endif
}
