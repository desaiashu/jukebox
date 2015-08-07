//
//  Friend.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import RealmSwift

class Friend : Object {
    dynamic var firstName: String = ""
    dynamic var lastName: String = ""
    dynamic var phoneNumber: String = ""
    dynamic var numShared: Int = 0
    dynamic var lastShared: Int = 0
    
    override class func primaryKey() -> String {
        return "phoneNumber"
    }
    
    override static func indexedProperties() -> [String] {
        return ["firstName", "lastName"]
    }
}
