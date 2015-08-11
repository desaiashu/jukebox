//
//  SelectSongTableViewCell.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class SelectSongTableViewCell: UITableViewCell {
    
    static var rowHeight: CGFloat = 80.0
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    
    var song: SendSong? {
        didSet {
            if let song = song {
                self.titleLabel.text = song.title
                self.artistLabel.text = song.artist
                
                self.playButton.enabled = true
                //Might want to do this once in intializer
                self.playButton.setTitle("...", forState: UIControlState.Disabled)
                self.playButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
            }
        }
    }
    
    @IBAction func playPressed(sender: UIButton) {
        self.song!.play()
        
        self.playButton.enabled = false
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(10 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
            if let playButton = self.playButton {
                playButton.enabled = true
            }
        }
    }
}
