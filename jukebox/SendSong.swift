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
    @objc dynamic var yt_id: String = ""
    @objc dynamic var title: String = ""
    @objc dynamic var artist: String = ""
    @objc dynamic var recipients: String = ""
    @objc dynamic var date: Int = 0
    
    func play() {
        SongPlayer.songPlayer.play(self.yt_id, title: self.title, artist: self.artist)
    }
}
