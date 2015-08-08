//
//  InboxSongTableViewCell.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class InboxSongTableViewCell: UITableViewCell {
    
    static var rowHeight: CGFloat = 80.0
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var senderLabel: UILabel!
    @IBOutlet weak var directionLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    var song: InboxSong? {
        didSet {
            if let song = song {
                self.titleLabel.text = song.title
                self.artistLabel.text = song.artist
                self.senderLabel.text = song.sender
                
                var friendNumber: String?
                if song.sender == User.user.phoneNumber {
                    friendNumber = song.recipient
                    self.directionLabel.text = "to"
                    self.backgroundColor = UIColor.whiteColor()
                } else {
                    friendNumber = song.sender
                    self.directionLabel.text = "from"
                    if song.listen {
                        self.backgroundColor = UIColor.whiteColor()
                    } else {
                        self.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.1)
                    }
                }
                //Might want to cache this in song download
                if let friendName = realm.objects(Friend).filter("phoneNumber == %@", friendNumber!).first?.firstName {
                    self.senderLabel.text = friendName
                } else {
                    self.senderLabel.text = friendNumber
                }
            }
        }
    }
    
    @IBAction func playPressed(sender: UIButton) {
        self.song?.play()
        self.backgroundColor = UIColor.whiteColor()
    }
}
