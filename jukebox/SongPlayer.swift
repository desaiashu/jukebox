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

struct PlaylistSong: Equatable {
    var yt_id: String
    var title: String
    var artist: String
}
func ==(lhs: PlaylistSong, rhs: PlaylistSong) -> Bool {
    return lhs.yt_id == rhs.yt_id
}

class SongPlayer : NSObject{
    static let songPlayer = SongPlayer()
    
    weak var playerButton: UIButton!
    weak var artistLabel: UILabel!
    weak var titleLabel: UILabel!
    
    private var player1Context = 0
    private var player2Context = 0
    dynamic var videoPlayerController1 = XCDYouTubeVideoPlayerViewController()
    dynamic var videoPlayerController2 = XCDYouTubeVideoPlayerViewController()
    var firstPlayer = true
    
    var playlist: [PlaylistSong]!
    var currentSongIndex = -1
    
    func setup(playerButton: UIButton, artistLabel: UILabel, titleLabel: UILabel) {
        
        self.playerButton = playerButton
        self.artistLabel = artistLabel
        self.titleLabel = titleLabel
        
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
        self.firstPlayer = true
        self.playerButton.titleLabel?.text = "Play"
        
        let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false").sorted("date", ascending: false)
        let newSongs = reduce(newInboxSongs, []) { $0 + ( !contains($0, PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist) ) ? [PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)] : [] ) }
        
        let oldInboxSongs = realm.objects(InboxSong).filter("listen == true AND mute == false").sorted("date", ascending: false)
        let oldSongs = reduce(oldInboxSongs, []) { $0 + ( !contains($0, PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist) ) ? [PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)] : [] ) }
        
        self.playlist = newSongs + self.shuffle(oldSongs)
        
        self.videoPlayerController1.videoIdentifier = self.playlist[0].yt_id
        self.titleLabel.text = self.playlist[0].title
        self.artistLabel.text = self.playlist[0].artist
        
        if self.playlist.count > 1 {
            self.videoPlayerController2.videoIdentifier = self.playlist[1].yt_id
        }
    }
    
    func shuffle<C: MutableCollectionType where C.Index == Int>(var list: C) -> C {
        let c = count(list)
        if c < 2 { return list }
        for i in 0..<(c - 1) {
            let j = Int(arc4random_uniform(UInt32(c - i))) + i
            swap(&list[i], &list[j])
        }
        return list
    }
    
    func updatePlaylist() {
        //Find unlistened to songs that are not on playlist, insert them immediately after current index + set video identifier of secondary player
        let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false").sorted("date")
        let newSongs = reduce(newInboxSongs, []) { $0 + ( !contains(self.playlist, PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)) && !contains($0, PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)) ? [PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)] : [] ) }
        
        let nextIndex = currentSongIndex+1
        for song in newSongs {
            playlist.insert(song, atIndex: nextIndex)
        }
        self.videoPlayerController2.videoIdentifier = self.playlist[nextIndex].yt_id
    }
    
    func toggleMute(yt_id: String, title: String, artist: String, mute: Bool) {
        if mute {
            self.mute(yt_id, title: title, artist: artist)
        } else {
            self.unmute(yt_id, title: title, artist: artist)
        }
    }
    
    func mute(yt_id: String, title: String, artist: String) {
        //If mute, remove songs from playlist IF song is after current index
        //      If song removed is next index, set identifier for second player (unless no songs left)
        if let index = find(self.playlist, PlaylistSong(yt_id: yt_id, title: title, artist: artist)) {
            if index > currentSongIndex {
                self.playlist.removeAtIndex(index)
                if index == currentSongIndex+1 && index != self.playlist.count {
                    self.videoPlayerController2.videoIdentifier = self.playlist[index].yt_id
                }
            }
        }
    }
    
    func unmute(yt_id: String, title: String, artist: String) {
        //If unmute, add song to end of playlist
        //      If end of playlist is next song, set identifier for second player
        self.playlist.append(PlaylistSong(yt_id: yt_id, title: title, artist: artist))
        if currentSongIndex+1 == self.playlist.count-1 {
            self.videoPlayerController2.videoIdentifier = self.playlist[currentSongIndex+1].yt_id
        }
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
        
        self.setNowPlaying(yt_id, title: title, artist: artist)
        self.playerButton.titleLabel?.text = "Pause"
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
            self.setNowPlaying(song.yt_id, title: song.title, artist: song.artist)
            
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
    
    func setNowPlaying(yt_id: String, title: String, artist: String) {
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
        
        self.triggerListen(yt_id)
    }
    
    func triggerListen(yt_id: String) {
        //Note, listen is set to true even if user listens to same song via search, or same song sent by other friend
        realm.write() {
            for sameSong in realm.objects(InboxSong).filter("yt_id = %@, recipient = %@", yt_id, User.user.phoneNumber)
            {
                if !sameSong.listen {
                    sameSong.listen = true
                    Server.server.listen(sameSong)
                }
            }
        }
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
            self.setNowPlaying(song.yt_id, title: song.title, artist: song.artist)
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
        } //TODO handle if nothing is playing
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
                self.play()
            } else if event.subtype == UIEventSubtype.RemoteControlPause {
                self.pause()
            } else if event.subtype == UIEventSubtype.RemoteControlNextTrack {
                self.skip()
            } //TODO, handle going previous track
        }
    }
}