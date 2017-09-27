//
//  InboxSongTableViewCell.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class InboxSongTableViewCell: UITableViewCell {
    
    static var rowHeight: CGFloat = 75.0
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var senderLabel: UILabel!
    @IBOutlet weak var directionLabel: UILabel!
    @IBOutlet weak var heartButton: UIButton!
    @IBOutlet weak var separator: UIImageView!
    
    var song: InboxSong? {
        didSet {
            if let song = song {
                self.titleLabel.text = song.title
                self.artistLabel.text = song.artist
                self.senderLabel.text = song.sender
                
                //self.playButton.isEnabled = true
                //Might want to do this once in intializer
//                self.playButton.setTitle("...", for: UIControlState.disabled)
//                self.playButton.setTitleColor(UIColor.lightGray, for: UIControlState.disabled)
                
                var friendNumber: String?
                if song.sender == User.user.phoneNumber {
                    friendNumber = song.recipient
                    if song.love {
                        self.directionLabel.text = "loved by"
                        self.heartButton.setImage(#imageLiteral(resourceName: "like_green"), for: UIControlState.normal)
                    } else {
                        self.directionLabel.text = "to"
                        self.heartButton.setImage(#imageLiteral(resourceName: "like_green_outline"), for: UIControlState.normal)
                    }
                    self.backgroundColor = UIColor.white
                    self.separator.image = #imageLiteral(resourceName: "line_light_green")
                    self.separator.contentMode = UIViewContentMode.left
                } else {
                    friendNumber = song.sender
                    if song.love {
                        self.directionLabel.text = "you love"
                        self.heartButton.setImage(#imageLiteral(resourceName: "like_purple"), for: UIControlState.normal)
                    } else {
                        self.directionLabel.text = "from"
                        self.heartButton.setImage(#imageLiteral(resourceName: "like_purple_outline"), for: UIControlState.normal)
                    }
                    if song.listen {
                        self.backgroundColor = UIColor.white
                    } else {
                        self.backgroundColor = UIColor(red: 82.0/255.0, green: 147.0/255.0, blue: 141.0/255.0, alpha: 0.1)
                    }
                    self.separator.image = #imageLiteral(resourceName: "line_light_purple")
                    self.separator.contentMode = UIViewContentMode.right
                }
                //Might want to cache this in song download
                if let friendName = realm.objects(Friend.self).filter("phoneNumber == %@", friendNumber!).first?.firstName {
                    self.senderLabel.text = friendName
                } else {
                    self.senderLabel.text = friendNumber
                }
            }
        }
    }
    
    @IBAction func heartPressed(_ sender: UIButton) {
        if let song = self.song {
            if song.sender != User.user.phoneNumber && !song.love {
                self.directionLabel.text = "you love"
                self.heartButton.setImage(#imageLiteral(resourceName: "like_purple"), for: UIControlState.normal)
                self.heartButton.isEnabled = false
                song.heart()
            }
        }
    }
    
    @IBAction func playPressed(_ sender: UIButton) {
        self.play()
    }
    
    func play() {
        //TODO introduce delay + buffering animation for playing
        self.song?.play()
        self.backgroundColor = UIColor.white
        
        //self.playButton.isEnabled = false
        self.checkBuffering()
    }
    
    func checkBuffering() {
        if !SongPlayer.songPlayer.buffering {
//            if let playButton = self.playButton {
//                playButton.isEnabled = true
//            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                self.checkBuffering()
            }
        }
        
    }
}
