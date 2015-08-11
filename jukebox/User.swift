//
//  User.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import RealmSwift

class User : Object {
    static var user = User()
    
    dynamic var phoneNumber: String = ""
    dynamic var code: String = ""
    dynamic var lastUpdated: Int = 0
    dynamic var firstName: String = ""
    dynamic var lastName: String = ""
    dynamic var pushToken: String = ""
    dynamic var addressBookLoaded: Bool = false
}
