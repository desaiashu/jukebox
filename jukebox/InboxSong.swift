//
//  InboxSong.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import RealmSwift

class InboxSong : Object {
    dynamic var sender: String = ""
    dynamic var recipient: String = ""
    dynamic var title: String = ""
    dynamic var artist: String = ""
    dynamic var yt_id: String = ""
    dynamic var date: Int = 0
    dynamic var updated: Int = 0
    dynamic var listened: Bool = false
    dynamic var loved: Bool = false
    
    override static func indexedProperties() -> [String] {
        return ["date"]
    }
}
