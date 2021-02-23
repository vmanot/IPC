//
// Copyright (c) Vatsal Manot
//

#if canImport(XPC)

import Swift
import XPC

public struct XPCCodingKey: CodingKey {
    public let stringValue: String
    
    public init?(stringValue: String) {
        self.intValue = nil
        self.stringValue = stringValue
    }
    
    public let intValue: Int?
    
    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
    
    public init(intValue: Int, stringValue: String) {
        self.intValue = intValue
        self.stringValue = stringValue
    }
    
    internal static let superKey = XPCCodingKey(intValue: 0, stringValue: "super")
}

#endif
