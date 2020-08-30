//
// Copyright (c) Vatsal Manot
//

import Foundation
#if os(macOS) || targetEnvironment(macCatalyst)
import ServiceManagement
#endif
import Swift

public struct MachServiceAuthorizationRight {
    enum Error: Swift.Error {
        case unsupportedPlatform
    }
    
    let command: Selector
    let name: String
    let description: String
    let ruleCustom: [String: Any]?
    let ruleConstant: String?
    
    public init(
        command: Selector,
        name: String,
        description: String,
        ruleCustom: [String: Any]? = nil,
        ruleConstant: String? = nil
    ) {
        self.command = command
        self.name = name
        self.description = description
        self.ruleCustom = ruleCustom
        self.ruleConstant = ruleConstant
    }
    
    func toAuthorizationRightDefinition() throws -> CFTypeRef {
        #if os(macOS) || targetEnvironment(macCatalyst)
        let result: CFTypeRef
        
        if let ruleCustom = self.ruleCustom as CFDictionary? {
            result = ruleCustom
        } else if let ruleConstant = self.ruleConstant as CFString? {
            result = ruleConstant
        } else {
            #if os(macOS)
            result = kAuthorizationRuleAuthenticateAsAdmin as CFString
            #else
            throw Error.unsupportedPlatform
            #endif
        }
        
        return result
        #else
        throw Error.unsupportedPlatform
        #endif
    }
}

let kAuthorizationRightKeyClass     = "class"
let kAuthorizationRightKeyGroup     = "group"
let kAuthorizationRightKeyRule      = "rule"
let kAuthorizationRightKeyTimeout   = "timeout"
let kAuthorizationRightKeyVersion   = "version"
let kAuthorizationFailedExitCode    = NSNumber(value: 503340)
