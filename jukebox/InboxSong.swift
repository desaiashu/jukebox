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
    dynamic var id: String = ""
    dynamic var sender: String = ""
    dynamic var recipient: String = ""
    dynamic var title: String = ""
    dynamic var artist: String = ""
    dynamic var yt_id: String = ""
    dynamic var date: Int = 0
    dynamic var updated: Int = 0
    dynamic var listen: Bool = false
    dynamic var love: Bool = false
    dynamic var mute: Bool = false
    
    override class func primaryKey() -> String? {
        return "id"
    }
    
    override static func indexedProperties() -> [String] {
        return ["date"]
    }
    
    func heart() {
        if !self.love {
            Server.love(self)
        }
    }
    
    func play() {
        //Keep track of which cell is being played
        //Loading indicator
        //Toggle into "stop" button
        //Build out player class
        
        SongPlayer.play(self.yt_id)
        
        if !self.listen && self.sender != User.user.phoneNumber {
            Server.listen(self)
        }
    }
}
