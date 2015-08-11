//
//  SongPlayer.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import XCDYouTubeKit
import AVFoundation
import Foundation

class SongPlayer : NSObject{
    static let songPlayer = SongPlayer()
    
    weak var titleLabel: UILabel!
    weak var artistLabel: UILabel!
    weak var playerButton: UIButton!
    
    dynamic var videoPlayerController1 = XCDYouTubeVideoPlayerViewController()
    dynamic var videoPlayerController2 = XCDYouTubeVideoPlayerViewController()
    var firstPlayer = true
    var playlist: [SendSong]?
    var currentSongIndex = -1
    
    private var player1Context = 0
    private var player2Context = 0
    
    override init() {
        super.init()
        
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error:nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        //Create players
        self.videoPlayerController1.preferredVideoQualities = [XCDYouTubeVideoQuality.Small240.rawValue]
        self.videoPlayerController1.moviePlayer.backgroundPlaybackEnabled = true
        
        self.videoPlayerController2.preferredVideoQualities = [XCDYouTubeVideoQuality.Small240.rawValue]
        self.videoPlayerController2.moviePlayer.backgroundPlaybackEnabled = true
        
        NSNotificationCenter.defaultCenter().removeObserver(self.videoPlayerController1, name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController1.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackDidFinish:", name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController1.moviePlayer)
        self.videoPlayerController1.addObserver(self, forKeyPath: "moviePlayer.contentURL", options: NSKeyValueObservingOptions.New, context:&player1Context)
        
        NSNotificationCenter.defaultCenter().removeObserver(self.videoPlayerController2, name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController2.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackDidFinish:", name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController2.moviePlayer)
        self.videoPlayerController2.addObserver(self, forKeyPath: "moviePlayer.contentURL", options: NSKeyValueObservingOptions.New, context:&player2Context)
        
        self.createPlaylist()
    }
    
    func createPlaylist() {
        firstPlayer = true
        playerButton.titleLabel?.text = "Play"
        
        
        //if playlist length == 0
        //      Disable all buttons
        //if playlist length > 0
        //      Set identifier for song 1
        //if playlist length > 1
        //      Set identifier for song 2?
    }
    
    func prependNewSongs() {
        //Find unlistened to songs that are not on playlist, insert them immediately after current index + set video identifier of secondary player
    }
    
    func mute(yt_id: String, mute: Bool) {
        //If mute, remove songs from playlist IF song is after current index
        //      If playlist is empty
        //      If song removed is the only song remaining in playist
        //If unmute, add song to end of playlist
        //      If playlist size is 1, enable all buttons.
        //      If end of playlist is next song, set identifier for second player
    }
    
    //When play on cell tapped
    func play(yt_id: String, title: String, artist: String) {
        
        var primaryVideoPlayerController = self.videoPlayerController1
        var secondaryVideoPlayerController = self.videoPlayerController2
        
        if currentSongIndex == -1 { //Covers when play is tapped on cell first
            firstPlayer = false
        }
        
        if !firstPlayer {
            primaryVideoPlayerController = self.videoPlayerController2
            secondaryVideoPlayerController = self.videoPlayerController1
        }
        
        primaryVideoPlayerController.videoIdentifier = yt_id
        
        self.setNowPlaying(title, artist: artist)
        self.playerButton.titleLabel?.text = "Pause"
        
        currentSongIndex-- // Essentially
    }
    
    //When song naturally finishes or is skipped
    @objc func playbackDidFinish(notification: NSNotification){
        
        let numSongs = playlist!.count
        currentSongIndex++
        if currentSongIndex != numSongs {
            //Swap players!
            self.firstPlayer = !self.firstPlayer
            
            //Play new primary player!
            var primaryVideoPlayerController = self.videoPlayerController1
            var secondaryVideoPlayerController = self.videoPlayerController2
            if !firstPlayer {
                primaryVideoPlayerController = self.videoPlayerController2
                secondaryVideoPlayerController = self.videoPlayerController1
            }
            primaryVideoPlayerController.moviePlayer.play()
            
            let song = playlist![currentSongIndex]
            self.setNowPlaying(song.title, artist: song.artist)
            
            self.prependNewSongs()
            
            if currentSongIndex+1 != numSongs {
                secondaryVideoPlayerController.videoIdentifier = playlist![currentSongIndex+1].yt_id
            }
        } else {
            self.createPlaylist()
        }
    }
    
    //When song id is set on player
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == &player1Context {
            if self.playerButton.titleLabel?.text == "Pause" {
                if self.firstPlayer { //When play in cell is tapped
                    self.videoPlayerController1.moviePlayer.play()
                } else { //When song naturally finshes or is skipped
                    self.videoPlayerController1.moviePlayer.prepareToPlay()
                }
            } else {
                self.videoPlayerController1.moviePlayer.prepareToPlay()
            }
        } else if context == &player2Context {
            if self.playerButton.titleLabel?.text == "Pause" {
                if !self.firstPlayer { //When play in cell is tapped
                    self.videoPlayerController2.moviePlayer.play()
                } else { //When song naturally finshes or is skipped
                    self.videoPlayerController2.moviePlayer.prepareToPlay()
                }
            }
        }
    }
    
    func setNowPlaying(title: String, artist: String) {
        self.titleLabel.text = title
        self.artistLabel.text = artist
        let image:UIImage = UIImage(named: "music512")!
        let albumArt = MPMediaItemArtwork(image: image)
        var songInfo: NSMutableDictionary = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyArtwork: albumArt,
        ]
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo as [NSObject : AnyObject]
    }
    
    func playerButtonPressed() {
        if self.playerButton.titleLabel?.text == "Play" {
            SongPlayer.songPlayer.play()
        } else {
            SongPlayer.songPlayer.pause()
        }
    }
    
    func play() {
        if self.currentSongIndex == -1 { //When play is tapped on widget first
            currentSongIndex++
            let song = self.playlist![self.currentSongIndex]
            self.setNowPlaying(song.title, artist: song.artist)
            if self.playlist?.count > 1 {
                self.videoPlayerController2.moviePlayer.prepareToPlay()
            }
        }
        if self.firstPlayer {
            self.videoPlayerController1.moviePlayer.play()
        } else {
            self.videoPlayerController2.moviePlayer.play()
        }
        self.playerButton.titleLabel?.text = "Pause"
    }
    
    func pause() {
        if self.firstPlayer {
            self.videoPlayerController1.moviePlayer.pause()
        } else {
            self.videoPlayerController2.moviePlayer.pause()
        }
        self.playerButton.titleLabel?.text = "Play"
    }
    
    func skip() {
        if self.firstPlayer {
            self.videoPlayerController1.moviePlayer.stop()
        } else {
            self.videoPlayerController2.moviePlayer.stop()
        }
    }
    
    func stop() {
        if self.firstPlayer {
            self.videoPlayerController1.moviePlayer.stop()
        } else {
            self.videoPlayerController2.moviePlayer.stop()
        }
    }
    
    func remoteControlReceivedWithEvent(event: UIEvent) {
        if event.type == UIEventType.RemoteControl {
            if event.subtype == UIEventSubtype.RemoteControlPlay {
                println("received remote play")
                self.play()
            } else if event.subtype == UIEventSubtype.RemoteControlPause {
                println("received remote pause")
                self.pause()
            } else if event.subtype == UIEventSubtype.RemoteControlTogglePlayPause {
                println("received toggle")
            }
        }
    }
}