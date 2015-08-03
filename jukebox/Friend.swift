//
//  Friend.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import RealmSwift

class Friend : Object {
    dynamic var firstName: String = ""
    dynamic var lastName: String = ""
    dynamic var phoneNumber: String = ""
    
    override static func indexedProperties() -> [String] {
        return ["firstName", "lastName", "phoneNumber"]
    }
}
