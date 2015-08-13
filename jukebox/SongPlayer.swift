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
    weak var skipButton: UIButton!
    
    var player = AVQueuePlayer() //Actual audio player
    
    var playlist: [PlaylistSong] = []
    var loadeditems = 0
    var currentSongIndex = 0
    
    func setup(playerButton: UIButton, artistLabel: UILabel, titleLabel: UILabel, skipButton: UIButton) {
        
        self.playerButton = playerButton
        self.artistLabel = artistLabel
        self.titleLabel = titleLabel
        self.skipButton = skipButton
        
        self.playerButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        self.playerButton.setTitle("...", forState: UIControlState.Disabled)
        self.skipButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error:nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        self.createPlaylist(nil)
    }
    
    func createPlaylist(startingSong:PlaylistSong?) {
        
        self.player.pause()
        self.player.removeAllItems()
        self.loadeditems = 0
        self.currentSongIndex = 0
        
        if var song = startingSong {
            if let index = find(self.playlist, song), let item = self.playlist[index].item {
                song.item = item
                self.loadeditems++
                self.player.insertItem(item, afterItem: nil)
            }
            self.playlist = [song]
        } else {
            self.playlist = []
            self.playerButton.setTitle("Play", forState: UIControlState.Normal)
        }
        
        let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false AND recipient == %@", User.user.phoneNumber).sorted("date", ascending: false)
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
            if self.playlist.count > loadeditems { // If statement covers case where playlist is only 1 long
                self.getStreamUrl(self.playlist[loadeditems].yt_id)
            }
            self.setNowPlaying()
        }
    }
    
    func getStreamUrl(yt_id: String) {
        XCDYouTubeClient.defaultClient().getVideoWithIdentifier(yt_id, completionHandler: { video, error in
            
            var streamUrl: NSURL?
            if let e = error {
                if error.domain == XCDYouTubeVideoErrorDomain {
                    if error.code == XCDYouTubeErrorCode.RestrictedPlayback.rawValue {
                        var objectsToDelete = realm.objects(InboxSong).filter("yt_id == %@", yt_id)
                        realm.write(){
                            realm.delete(objectsToDelete)
                        }
                        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
                            inboxViewController.tableView.reloadData()
                        }
                    }
                }
            } else {
                if var u140 = video.streamURLs[140] as? NSURL{
                    streamUrl = u140
                } else if var u36 = video.streamURLs[XCDYouTubeVideoQuality.Small240.rawValue] as? NSURL{
                    streamUrl = u36
                }
            }
            if let url = streamUrl {
                println(self.playlist[self.loadeditems].title)
                
                var playerItem = AVPlayerItem(URL: url)
                self.playlist[self.loadeditems].item = playerItem
                NSNotificationCenter.defaultCenter().addObserver(self, selector: "songDidEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: playerItem)
                self.player.insertItem(playerItem, afterItem: nil)
                
                self.loadeditems++
                if self.loadeditems-1 == self.currentSongIndex && !self.playerButton.enabled {
                    self.playerButton.enabled = true
                    self.triggerListen()
                }
            } else {
                self.playlist.removeAtIndex(self.loadeditems)
            }
            
            if self.loadeditems < self.playlist.count {
                self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
            }
        })
    }
    
    func updatePlaylist() {
        if self.playlist.count != 0 { //Off chance inbox hasn't downloaded when you first login
            //Do I simply want to create a new playlist starting with currently playing song? There's a slight hiccup
            //Find unlistened to songs that are not on playlist, insert them at end of playlist
            let unloaded = self.playlist.count - self.loadeditems
            
            let newInboxSongs = realm.objects(InboxSong).filter("mute == false").sorted("date")
            self.playlist = reduce(newInboxSongs, self.playlist) { $0 +
                (!contains(self.playlist, playlistSongFromInboxSong($1)) &&
                    !contains($0, playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }

            if unloaded == 0 && self.loadeditems < self.playlist.count { //Load new songs
                self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
            }
        }
    }
    
    //When play on cell tapped
    func play(yt_id: String, title: String, artist: String) {
        self.createPlaylist(PlaylistSong(yt_id: yt_id, title: title, artist: artist, item: nil))
        self.play()
    }
    
    func playerButtonPressed() {
        if self.playerButton.titleLabel?.text == "Play" {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func play() {
        if self.loadeditems == 0 {
            self.playerButton.enabled = false
        } else {
            self.triggerListen()
        }
        self.player.play()
        self.playerButton.setTitle("Pause", forState: UIControlState.Normal)
    }
    
    func pause() {
        self.player.pause()
        self.playerButton.setTitle("Play", forState: UIControlState.Normal)
    }
    
    func skip() {
        if self.playerButton.enabled { //Protecting against the "loading" case
            self.player.advanceToNextItem()
            self.nextSong()
            self.skipButton.enabled = false //Protecting against hammering on skip button
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                self.skipButton.enabled = true
            }
        }
    }
    
    func nextSong() {
        self.currentSongIndex++
        if currentSongIndex >= self.playlist.count {
            self.createPlaylist(nil)
        } else {
            self.setNowPlaying()
            if self.loadeditems < self.currentSongIndex { //If url hasn't loaded for next song
                self.playerButton.enabled = false
            } else {
                if self.player.rate == 1.0 {
                    self.triggerListen()
                }
            }
        }
    }
    
    func songDidEnd(notification: NSNotification) {
        self.nextSong()
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
            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
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
    }
    
    func triggerListen() {
        let yt_id = self.playlist[currentSongIndex].yt_id
        //Note, listen is set to true even if user listens to same song via search, or same song sent by other friend
        for sameSong in realm.objects(InboxSong).filter("yt_id == %@ AND recipient == %@", yt_id, User.user.phoneNumber)
        {
            sameSong.hear()
        }
        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
        if let inboxViewController = navigationController.topViewController as? InboxViewController {
            inboxViewController.tableView.reloadData()
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
}