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
                
                self.playButton.isEnabled = true
                //Might want to do this once in intializer
                self.playButton.setTitle("...", for: UIControlState.disabled)
                self.playButton.setTitleColor(UIColor.lightGray, for: UIControlState.disabled)
            }
        }
    }
    
    @IBAction func playPressed(_ sender: UIButton) {
        self.song!.play()
        
        self.playButton.isEnabled = false
        self.checkBuffering()
    }
    
    func checkBuffering() {
        if !SongPlayer.songPlayer.buffering {
            if let playButton = self.playButton {
                playButton.isEnabled = true
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                self.checkBuffering()
            }
        }
        
    }
}
