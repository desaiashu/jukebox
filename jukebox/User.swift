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
    
    @objc dynamic var phoneNumber: String = ""
    @objc dynamic var code: String = ""
    @objc dynamic var lastUpdated: Int = 0
    @objc dynamic var firstName: String = ""
    @objc dynamic var lastName: String = ""
    @objc dynamic var pushToken: String = ""
    @objc dynamic var addressBookLoaded: Bool = false
}
