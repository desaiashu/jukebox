//
//  SelectSongTableViewCell.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class SelectSongTableViewCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var previewButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    
    var song: SearchSong? {
        didSet {
            if let song = song {
                self.titleLabel.text = song.title
                self.artistLabel.text = song.artist
            }
        }
    }
    
    @IBAction func previewPressed(sender: UIButton) {
        g.player.play(song!.yt_id)
    }
}
