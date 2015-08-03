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
    dynamic var phone_number: String = ""
    dynamic var code: String = ""
    dynamic var last_updated: Int = 0
    dynamic var last_sent: Int = 0
    dynamic var first_name: String = ""
    dynamic var last_name: String = ""
}
