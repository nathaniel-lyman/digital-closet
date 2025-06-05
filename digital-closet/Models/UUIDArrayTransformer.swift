//
//  UUIDArrayTransformer.swift
//  digital-closet
//
//  Custom transformer for converting arrays of UUID to Data and back
//

import Foundation
import CoreData

@objc(UUIDArrayTransformer)
final class UUIDArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    
    // MARK: - Class Properties
    
    /// The name of the transformer. This is used to register the transformer with Core Data.
    static let name = NSValueTransformerName(rawValue: String(describing: UUIDArrayTransformer.self))
    
    // MARK: - Overrides
    
    /// Specifies the class that instances will be transformed to
    override static var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, NSUUID.self]
    }
    
    /// Transforms a value from one representation to another
    override func transformedValue(_ value: Any?) -> Any? {
        guard let uuidArray = value as? [UUID] else {
            return super.transformedValue(value)
        }
        
        // Convert Swift UUID array to NSArray of NSUUID for archiving
        let nsUUIDArray = uuidArray.map { NSUUID(uuidString: $0.uuidString)! }
        return super.transformedValue(nsUUIDArray)
    }
    
    /// Reverses the transformation of a value from one representation to another
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else {
            return nil
        }
        
        // First unarchive to get NSArray
        guard let nsArray = super.reverseTransformedValue(data) as? NSArray else {
            return nil
        }
        
        // Convert NSArray of NSUUID back to Swift UUID array
        let uuidArray = nsArray.compactMap { element -> UUID? in
            if let nsUUID = element as? NSUUID {
                return UUID(uuidString: nsUUID.uuidString)
            }
            return nil
        }
        
        return uuidArray
    }
    
    // MARK: - Registration
    
    /// Registers the transformer with the ValueTransformer registry
    static func register() {
        let transformer = UUIDArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
} 