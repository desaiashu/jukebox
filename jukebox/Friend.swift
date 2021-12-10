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
    @objc dynamic var firstName: String = ""
    @objc dynamic var lastName: String = ""
    @objc dynamic var phoneNumber: String = ""
    @objc dynamic var numShared: Int = 0
    @objc dynamic var lastShared: Int = 0
    
    override class func primaryKey() -> String {
        return "phoneNumber"
    }
    
    override static func indexedProperties() -> [String] {
        return ["firstName", "lastName"]
    }
}
