//
//  InboxSongTableViewCell.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class InboxSongTableViewCell: UITableViewCell {
    
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
                
                if song.sender == User.user.phoneNumber {
                    self.senderLabel.text = song.recipient
                    self.directionLabel.text = "to"
                } else {
                    self.senderLabel.text = song.sender
                    self.directionLabel.text = "from"
                }
                
            }
        }
    }
    
    @IBAction func playPressed(sender: UIButton) {
        //Keep track of which cell is being played
        //Loading indicator
        //Toggle into "stop" button
        //Send "listened" flag up to server
        //Build out player class
        
        SongPlayer.play(song!.yt_id)
    }
}
