//
//  SendSong.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import RealmSwift

class SendSong : Object {
    dynamic var title: String = ""
    dynamic var artist: String = ""
    dynamic var yt_id: String = ""
    dynamic var recipients: String = ""
    dynamic var date: String = ""
}
