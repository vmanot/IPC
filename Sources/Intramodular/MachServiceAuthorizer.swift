//
// Copyright (c) Vatsal Manot
//

#if os(macOS)

import Foundation
import ServiceManagement
import Swift

public class MachServiceAuthorizer {
    enum Error: Swift.Error {
        case failedToAcquireAuthorizationRef
        case invalidAuthorizationExternalFormData
        case failedToConvertAuthorizationExternalFormToReference
        case failedToAcquireCorrectAuthorizationRights(for: Selector)
        case failedToParseAuthorizationName
        case securityError(String)
    }
    
    let authorizationRights: [MachServiceAuthorizationRight]
    
    init(authorizationRights: [MachServiceAuthorizationRight]) {
        self.authorizationRights = authorizationRights
    }
    
    func authorizationRight(forCommand command: Selector) -> MachServiceAuthorizationRight? {
        return self.authorizationRights.first { $0.command == command }
    }
    
    func authorizationRightsUpdateDatabase() throws {
        guard let authRef = try self.emptyAuthorizationRef() else {
            throw Error.failedToAcquireAuthorizationRef
        }
        
        for authorizationRight in self.authorizationRights {
            
            var osStatus = errAuthorizationSuccess
            var currentRule: CFDictionary?
            
            osStatus = AuthorizationRightGet(authorizationRight.name, &currentRule)
            
            let isDefinitionUpdateRequired = try self.isUpdateRequired(current: currentRule, wanted: authorizationRight)
            
            if osStatus == errAuthorizationDenied || isDefinitionUpdateRequired {
                osStatus = AuthorizationRightSet(
                    authRef,
                    authorizationRight.name,
                    try authorizationRight.toAuthorizationRightDefinition(),
                    authorizationRight.description as CFString,
                    nil,
                    nil
                )
            }
            
            guard osStatus == errAuthorizationSuccess else {
                NSLog("AuthorizationRightSet or Get failed with error: \(String(describing: SecCopyErrorMessageString(osStatus, nil)))")
                continue
            }
        }
    }
    
    func isUpdateRequired(
        current currentRight: CFDictionary?,
        wanted wantedRight: MachServiceAuthorizationRight
    ) throws -> Bool {
        guard let currentRight = currentRight as? [String: Any] else {
            return true
        }
        
        let newRule = try wantedRight.toAuthorizationRightDefinition()
        
        if CFGetTypeID(newRule) == CFStringGetTypeID() {
            if let currentRule = currentRight[kAuthorizationRightKeyRule] as? [String],
               let newRule = wantedRight.ruleConstant {
                return currentRule != [newRule]
            }
        } else if CFGetTypeID(newRule) == CFDictionaryGetTypeID() {
            if let currentVersion = currentRight[kAuthorizationRightKeyVersion] as? Int,
               let newVersion = wantedRight.ruleCustom?[kAuthorizationRightKeyVersion] as? Int {
                return currentVersion != newVersion
            }
        }
        
        return true
    }
    
    // MARK: -
    // MARK: Authorization Wrapper
    
    private func executeAuthorizationFunction(_ authorizationFunction: () -> (OSStatus) ) throws {
        let osStatus = authorizationFunction()
        guard osStatus == errAuthorizationSuccess else {
            throw Error.securityError(String(describing: SecCopyErrorMessageString(osStatus, nil)))
        }
    }
    
    // MARK: -
    // MARK: AuthorizationRef
    
    func authorizationRef(_ rights: UnsafePointer<AuthorizationRights>?,
                          _ environment: UnsafePointer<AuthorizationEnvironment>?,
                          _ flags: AuthorizationFlags) throws -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        try executeAuthorizationFunction { AuthorizationCreate(rights, environment, flags, &authRef) }
        return authRef
    }
    
    func authorizationRef(fromExternalForm data: NSData) throws -> AuthorizationRef? {
        
        // Create an AuthorizationExternalForm from it's data representation
        var authRef: AuthorizationRef?
        let authRefExtForm: UnsafeMutablePointer<AuthorizationExternalForm> = UnsafeMutablePointer.allocate(capacity: kAuthorizationExternalFormLength * MemoryLayout<AuthorizationExternalForm>.size)
        memcpy(authRefExtForm, data.bytes, data.length)
        
        // Extract the AuthorizationRef from it's external form
        try executeAuthorizationFunction { AuthorizationCreateFromExternalForm(authRefExtForm, &authRef) }
        return authRef
    }
    
    
    // MARK: -
    // MARK: Empty Authorization Refs
    
    func emptyAuthorizationRef() throws -> AuthorizationRef? {
        var authRef: AuthorizationRef?
        
        // Create an empty AuthorizationRef
        try executeAuthorizationFunction { AuthorizationCreate(nil, nil, [], &authRef) }
        return authRef
    }
    
    func emptyAuthorizationExternalForm() throws -> AuthorizationExternalForm? {
        
        // Create an empty AuthorizationRef
        guard let authorizationRef = try self.emptyAuthorizationRef() else { return nil }
        
        // Make an external form of the AuthorizationRef
        var authRefExtForm = AuthorizationExternalForm()
        try executeAuthorizationFunction { AuthorizationMakeExternalForm(authorizationRef, &authRefExtForm) }
        return authRefExtForm
    }
    
    func emptyAuthorizationExternalFormData() throws -> NSData? {
        guard var authRefExtForm = try self.emptyAuthorizationExternalForm() else { return nil }
        
        // Encapsulate the external form AuthorizationRef in an NSData object
        return NSData(bytes: &authRefExtForm, length: kAuthorizationExternalFormLength)
    }
    
    // MARK: -
    // MARK: Verification
    
    func verify(authorizationData authExtData: NSData?, for command: Selector) throws {
        // Verity that the passed authExtData looks reasonable
        guard let authorizationExtData = authExtData, authorizationExtData.length == kAuthorizationExternalFormLength else {
            throw Error.invalidAuthorizationExternalFormData
        }
        
        // Convert the external form to an AuthorizationRef
        guard let authorizationRef = try self.authorizationRef(fromExternalForm: authorizationExtData) else {
            throw Error.failedToConvertAuthorizationExternalFormToReference
        }
        
        // Get the authorization right struct for the passed command
        guard let authorizationRight = self.authorizationRight(forCommand: command) else {
            throw Error.failedToAcquireCorrectAuthorizationRights(for: command)
        }
        
        // Verity the user has the right to run the passed command
        try self.verifyAuthorization(authorizationRef, forAuthenticationRight: authorizationRight)
    }
    
    func verifyAuthorization(_ authRef: AuthorizationRef, forAuthenticationRight authRight: MachServiceAuthorizationRight) throws {
        
        // Get the authorization name in the correct format
        guard let authRightName = (authRight.name as NSString).utf8String else {
            throw Error.failedToParseAuthorizationName
        }
        
        // Create an AuthorizationItem using the authorization right name
        var authorizationItem = AuthorizationItem(
            name: authRightName,
            valueLength: 0,
            value: UnsafeMutableRawPointer(bitPattern: 0),
            flags: 0
        )
        
        try withUnsafeMutablePointer(to: &authorizationItem) { authorizationItem in
            // Create the AuthorizationRights for using the AuthorizationItem
            var authorizationRights = AuthorizationRights(count: 1, items: authorizationItem)
            
            try executeAuthorizationFunction {
                AuthorizationCopyRights(
                    authRef,
                    &authorizationRights,
                    nil, [.extendRights, .interactionAllowed], nil
                )
            }
        }
    }
}

#endif
