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
func playlistSongFromInboxSong(song: InboxSong)->PlaylistSong {
    return PlaylistSong(yt_id: song.yt_id, title: song.title, artist: song.artist)
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
    
    //var player = AVQueuePlayer()
    
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
        self.videoPlayerController1.moviePlayer.shouldAutoplay = false
        self.videoPlayerController1.moviePlayer.repeatMode = MPMovieRepeatMode.None
        
        self.videoPlayerController2.preferredVideoQualities = [XCDYouTubeVideoQuality.Small240.rawValue]
        self.videoPlayerController2.moviePlayer.backgroundPlaybackEnabled = true
        self.videoPlayerController2.moviePlayer.shouldAutoplay = false
        self.videoPlayerController1.moviePlayer.repeatMode = MPMovieRepeatMode.None
        
        NSNotificationCenter.defaultCenter().removeObserver(self.videoPlayerController1, name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController1.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackDidFinish:", name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController1.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackDidChange:", name: MPMoviePlayerPlaybackStateDidChangeNotification, object: self.videoPlayerController1.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadingDidChange:", name: MPMoviePlayerLoadStateDidChangeNotification, object: self.videoPlayerController1.moviePlayer)
        self.videoPlayerController1.addObserver(self, forKeyPath: "moviePlayer.contentURL", options: NSKeyValueObservingOptions.New, context:&player1Context)
        
        NSNotificationCenter.defaultCenter().removeObserver(self.videoPlayerController2, name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController2.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackDidFinish:", name: MPMoviePlayerPlaybackDidFinishNotification, object: self.videoPlayerController2.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "playbackDidChange:", name: MPMoviePlayerPlaybackStateDidChangeNotification, object: self.videoPlayerController2.moviePlayer)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "loadingDidChange:", name: MPMoviePlayerLoadStateDidChangeNotification, object: self.videoPlayerController2.moviePlayer)
        self.videoPlayerController2.addObserver(self, forKeyPath: "moviePlayer.contentURL", options: NSKeyValueObservingOptions.New, context:&player2Context)
        
        self.createPlaylist()
    }
    
    func createPlaylist() {
        self.firstPlayer = true
        self.currentSongIndex = -1
        self.playerButton.setTitle("Play", forState: UIControlState.Normal)
        
        let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false").sorted("date", ascending: false)
        let newSongs = reduce(newInboxSongs, []) { $0 +
            ( !contains($0, playlistSongFromInboxSong($1))
                ? [playlistSongFromInboxSong($1)] : [] ) }
        
        let oldInboxSongs = realm.objects(InboxSong).filter("listen == true AND mute == false").sorted("date", ascending: false)
        let oldSongs = reduce(oldInboxSongs, []) { $0 +
                (!contains(newSongs, playlistSongFromInboxSong($1)) &&
                    !contains($0, playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }
        
        self.playlist = newSongs + self.shuffle(oldSongs)
        for song in self.playlist {
            println(song.title)
        }
        
        if self.playlist.count > 0 {
            self.videoPlayerController1.videoIdentifier = self.playlist[0].yt_id
            self.videoPlayerController2.videoIdentifier = self.playlist[1].yt_id
            self.titleLabel.text = self.playlist[0].title
            self.artistLabel.text = self.playlist[0].artist
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
        
        if self.playlist.count == 0 { //Off chance inbox hasn't downloaded when you first login
            self.createPlaylist()
        } else {
            //Find unlistened to songs that are not on playlist, insert them immediately after current index + set video identifier of secondary player
            let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false").sorted("date")
            let newSongs = reduce(newInboxSongs, []) { $0 + ( !contains(self.playlist, PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)) && !contains($0, PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)) ? [PlaylistSong(yt_id: $1.yt_id, title: $1.title, artist: $1.artist)] : [] ) }
            
            let nextIndex = currentSongIndex+1
            for song in newSongs {
                playlist.insert(song, atIndex: nextIndex)
            }
            self.videoPlayerController2.videoIdentifier = self.playlist[nextIndex].yt_id
        }
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
        
        if currentSongIndex == -1 { //Covers when play is tapped on cell before playlist started playing
            firstPlayer = false
        }
        
        currentSongIndex++
        self.playlist.insert(PlaylistSong(yt_id: yt_id, title: title, artist: artist), atIndex: currentSongIndex)
        
        var primaryVideoPlayerController = self.videoPlayerController1
        var secondaryVideoPlayerController = self.videoPlayerController2
        if !firstPlayer {
            primaryVideoPlayerController = self.videoPlayerController2
            secondaryVideoPlayerController = self.videoPlayerController1
        }
        
        primaryVideoPlayerController.videoIdentifier = yt_id
        
        self.setNowPlaying(yt_id, title: title, artist: artist)
        self.playerButton.setTitle("Pause", forState: UIControlState.Normal)
    }
    
    @objc func playbackDidChange(notification: NSNotification){
        var s: String!
        if let obj = (notification.object as? MPMoviePlayerController) {
            if obj == self.videoPlayerController1.moviePlayer {
                s = "1"
            } else if obj == self.videoPlayerController2.moviePlayer {
                s = "2"
            }
        }
        println(s+" playback state "+String(self.videoPlayerController1.moviePlayer.playbackState.rawValue))
    }
    
    @objc func loadingDidChange(notification: NSNotification){
        var s: String!
        if let obj = (notification.object as? MPMoviePlayerController) {
            if obj == self.videoPlayerController1.moviePlayer {
                s = "1"
            } else if obj == self.videoPlayerController2.moviePlayer {
                s = "2"
            }
        }
        println(s+" load state "+String(self.videoPlayerController1.moviePlayer.loadState.rawValue))
        println(self.videoPlayerController1.moviePlayer.contentURL)
    }
    
    //When song naturally finishes or is skipped
    @objc func playbackDidFinish(notification: NSNotification){
        
        if let obj = (notification.object as? MPMoviePlayerController) {
            if obj == self.videoPlayerController1.moviePlayer {
                println("1 did finish")
            } else if obj == self.videoPlayerController2.moviePlayer {
                println("2 did finish")
            }
        }
        
        let numSongs = playlist!.count
        currentSongIndex++
        if currentSongIndex < numSongs {
            //Swap players!
            self.firstPlayer = !self.firstPlayer
            
            //Play new primary player!
            var primaryVideoPlayerController = self.videoPlayerController1
            var secondaryVideoPlayerController = self.videoPlayerController2
            if !self.firstPlayer {
                primaryVideoPlayerController = self.videoPlayerController2
                secondaryVideoPlayerController = self.videoPlayerController1
                println("2 playing")
            } else {
                println("1 playing")
            }
            primaryVideoPlayerController.moviePlayer.play()
            
            let song = playlist![currentSongIndex]
            self.setNowPlaying(song.yt_id, title: song.title, artist: song.artist)
            self.triggerListen(song.yt_id)
            
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
            if currentSongIndex != -1 {
                if self.firstPlayer { //When play in cell is tapped
                    self.videoPlayerController1.moviePlayer.play()
                    println("1 playing")
                } else { //When song naturally finshes or is skipped
                    self.videoPlayerController1.moviePlayer.prepareToPlay()
                    println("1 preparing")
                }
            } else {
                self.videoPlayerController1.moviePlayer.prepareToPlay() //Prepare first song when creating playlist
                println("1 preparing")
                println(self.videoPlayerController1.moviePlayer.contentURL)
            }
        } else if context == &player2Context {
            if currentSongIndex != -1 {
                if !self.firstPlayer { //When play in cell is tapped
                    self.videoPlayerController2.moviePlayer.play()
                    println("2 playing")
                } else { //When song naturally finshes or is skipped
                    self.videoPlayerController2.moviePlayer.prepareToPlay()
                    println("2 preparing")
                }
            }
        }
    }
    
    func setNowPlaying(yt_id: String, title: String, artist: String) {
        println("now playing")
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
    
    func triggerListen(yt_id: String) {
        //Note, listen is set to true even if user listens to same song via search, or same song sent by other friend
        for sameSong in realm.objects(InboxSong).filter("yt_id == %@ AND recipient == %@ AND listen == false", yt_id, User.user.phoneNumber)
        {
            sameSong.hear()
        }
        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
        if let inboxViewController = navigationController.topViewController as? InboxViewController {
            inboxViewController.tableView.reloadData()
        }
    }
    
    func playerButtonPressed() {
        if self.playerButton.titleLabel?.text == "Play" {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func play() {
        if self.firstPlayer {
            self.videoPlayerController1.moviePlayer.play()
            println("1 playing")
        } else {
            self.videoPlayerController2.moviePlayer.play()
            println("2 playing")
        }
        if self.currentSongIndex == -1 { //When play is tapped on widget first
            currentSongIndex++
            let song = self.playlist![self.currentSongIndex]
            self.setNowPlaying(song.yt_id, title: song.title, artist: song.artist)
            if self.playlist.count > 1 {
                println("2 preparing")
                self.videoPlayerController2.moviePlayer.prepareToPlay()
            }
            self.triggerListen(song.yt_id)
        }
        self.playerButton.setTitle("Pause", forState: UIControlState.Normal)
    }
    
    func pause() {
        println("2 preparing")
        self.videoPlayerController2.moviePlayer.prepareToPlay()
        if self.firstPlayer {
            self.videoPlayerController1.moviePlayer.pause()
            println("1 paused")
        } else {
            self.videoPlayerController2.moviePlayer.pause()
            println("2 paused")
        }
        self.playerButton.setTitle("Play", forState: UIControlState.Normal)
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
            println("1 stopped")
        } else {
            self.videoPlayerController2.moviePlayer.stop()
            println("2 stopped")
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