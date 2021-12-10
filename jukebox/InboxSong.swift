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
    @objc dynamic var id: String = ""
    @objc dynamic var sender: String = ""
    @objc dynamic var recipient: String = ""
    @objc dynamic var title: String = ""
    @objc dynamic var artist: String = ""
    @objc dynamic var yt_id: String = ""
    @objc dynamic var date: Int = 0
    @objc dynamic var updated: Int = 0
    @objc dynamic var listen: Bool = false
    @objc dynamic var love: Bool = false
    @objc dynamic var mute: Bool = false
    
    override class func primaryKey() -> String? {
        return "id"
    }
    
    override static func indexedProperties() -> [String] {
        return ["date"]
    }
    
    func heart() {
        if !self.love {
            try! self.realm!.write() {
                self.love = true
            }
            Server.server.love(self)
        }
    }
    
    func hear() {
        if !self.listen {
            try! self.realm!.write() {
                self.listen = true
            }
            Server.server.listen(self)
        }
    }
    
    func play() {        
        SongPlayer.songPlayer.play(self.yt_id, title: self.title, artist: self.artist)
    }
}
