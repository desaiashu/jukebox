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
    var item: AVPlayerItem?
}
func ==(lhs: PlaylistSong, rhs: PlaylistSong) -> Bool {
    return lhs.yt_id == rhs.yt_id
}
func playlistSongFromInboxSong(song: InboxSong)->PlaylistSong {
    return PlaylistSong(yt_id: song.yt_id, title: song.title, artist: song.artist, item:nil)
}

class SongPlayer : NSObject{
    static let songPlayer = SongPlayer()
    
    weak var playerButton: UIButton!
    weak var artistLabel: UILabel!
    weak var titleLabel: UILabel!
    
    var videoPlayerContext = 0
    dynamic var videoPlayerController = XCDYouTubeVideoPlayerViewController() //Hack to get youtube urls
    
    var player = AVQueuePlayer() //Actual audio player
    
    var playlist: [PlaylistSong]!
    var loadeditems = 0
    var currentSongIndex = -1
    
    func setup(playerButton: UIButton, artistLabel: UILabel, titleLabel: UILabel) {
        
        self.playerButton = playerButton
        self.artistLabel = artistLabel
        self.titleLabel = titleLabel
        
        self.playerButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        self.playerButton.setTitle("...", forState: UIControlState.Disabled)
        
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error:nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        //Create players
        self.videoPlayerController.preferredVideoQualities = [XCDYouTubeVideoQuality.Small240.rawValue]
        self.videoPlayerController.addObserver(self, forKeyPath: "moviePlayer.contentURL", options: NSKeyValueObservingOptions.New, context:&videoPlayerContext)
        
        self.createPlaylist(nil)
    }
    
    func createPlaylist(startingSong:PlaylistSong?) {
        
        self.player.removeAllItems()
        self.loadeditems = 0
        self.currentSongIndex = -1
        
        if var song = startingSong {
            if let index = find(self.playlist, song) {
                song.item = self.playlist[index].item
                self.loadeditems++
                self.player.insertItem(song.item, afterItem: nil)
                self.player.play()
                self.setNowPlaying()
            } else {
                self.playlist = [song]
                self.playerButton.enabled = false
            }
            self.currentSongIndex++ //Will trigger play after url load if not loaded
            self.playerButton.setTitle("Pause", forState: UIControlState.Normal)
        } else {
            self.playlist = []
            self.playerButton.setTitle("Play", forState: UIControlState.Normal)
        }
        
        let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false").sorted("date", ascending: false)
        self.playlist = reduce(newInboxSongs, self.playlist) { $0 +
            ( !contains($0, playlistSongFromInboxSong($1))
                ? [playlistSongFromInboxSong($1)] : [] ) }
        
        let oldInboxSongs = realm.objects(InboxSong).filter("listen == true AND mute == false").sorted("date", ascending: false)
        let oldSongs = reduce(oldInboxSongs, []) { $0 +
                (!contains(self.playlist, playlistSongFromInboxSong($1)) &&
                    !contains($0, playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }
        
        self.playlist = self.playlist + self.shuffle(oldSongs)

        if self.playlist.count > 0 {
            if self.playlist.count > loadeditems { // In case playlist is only 1 long
                self.videoPlayerController.videoIdentifier = self.playlist[loadeditems].yt_id
            }
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
            self.createPlaylist(nil)
        } else {
            //Find unlistened to songs that are not on playlist, insert them immediately after current index + set video identifier of secondary player
            
            let unloaded = self.playlist.count - self.loadeditems
            
            let newInboxSongs = realm.objects(InboxSong).filter("mute == false").sorted("date")
            self.playlist = reduce(newInboxSongs, self.playlist) { $0 +
                (!contains(self.playlist, playlistSongFromInboxSong($1)) &&
                    !contains($0, playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }

            if unloaded == 0 && self.loadeditems < self.playlist.count { //Load new songs
                self.videoPlayerController.videoIdentifier = self.playlist[loadeditems].yt_id
            }
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
        if let index = find(self.playlist, PlaylistSong(yt_id: yt_id, title: title, artist: artist, item: nil)) {
            if index > self.currentSongIndex && index != loadeditems { //If it's currently loading, it will break stuff
                let playListSong = self.playlist.removeAtIndex(index)
                self.player.removeItem(playListSong.item)
                loadeditems--
            }
        }
    }
    
    func unmute(yt_id: String, title: String, artist: String) {
        //If unmute, add song to end of playlist
        self.playlist.append(PlaylistSong(yt_id: yt_id, title: title, artist: artist, item:nil))
        if self.loadeditems == self.playlist.count-1 {
            self.videoPlayerController.videoIdentifier = self.playlist[loadeditems].yt_id
        }
    }
    
    //When play on cell tapped
    func play(yt_id: String, title: String, artist: String) {
        self.createPlaylist(PlaylistSong(yt_id: yt_id, title: title, artist: artist, item: nil))
    }
    
    //When song id is set on player
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if context == &videoPlayerContext {
            var playerItem = AVPlayerItem(URL: self.videoPlayerController.moviePlayer.contentURL)
            self.playlist[loadeditems].item = playerItem
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "songDidEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)

            self.player.insertItem(playerItem, afterItem: nil)
            if self.loadeditems == self.currentSongIndex {
                self.player.play()
                self.setNowPlaying()
                self.playerButton.enabled = true
            }
            
            println(self.playlist[loadeditems].title)
            self.loadeditems++
            if loadeditems < self.playlist.count {
                self.videoPlayerController.videoIdentifier = self.playlist[loadeditems].yt_id
            }
        }
    }
    
    func songDidEnd(notification: NSNotification) {
        self.currentSongIndex++
        if currentSongIndex == self.playlist.count {
            self.createPlaylist(nil)
        } else if self.loadeditems < self.currentSongIndex { //If url hasn't loaded for next song
            self.playerButton.enabled = false
        } else {
            self.setNowPlaying()
        }
    }
    
    func setNowPlaying() {
        let playlistSong = self.playlist[currentSongIndex]
        self.titleLabel.text = playlistSong.title
        self.artistLabel.text = playlistSong.artist
        let image:UIImage = UIImage(named: "music512")!
        let albumArt = MPMediaItemArtwork(image: image)
        var songInfo: NSMutableDictionary = [
            MPMediaItemPropertyTitle: playlistSong.title,
            MPMediaItemPropertyArtist: playlistSong.artist,
            MPMediaItemPropertyArtwork: albumArt,
        ]
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = songInfo as [NSObject : AnyObject]
        self.triggerListen(playlistSong.yt_id)
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
        if self.player.items().count == 0 { //Odd case where first url isn't loaded
            self.currentSongIndex++
            self.playerButton.enabled = false
        } else {
            self.player.play()
            if self.currentSongIndex == -1 { //Playing for first time
                self.currentSongIndex++
                self.setNowPlaying()
            }
        }
        self.playerButton.setTitle("Pause", forState: UIControlState.Normal)
    }
    
    func pause() {
        self.player.pause()
        self.playerButton.setTitle("Play", forState: UIControlState.Normal)
    }
    
    func skip() {
        self.player.advanceToNextItem()
        self.currentSongIndex++
        self.setNowPlaying()
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