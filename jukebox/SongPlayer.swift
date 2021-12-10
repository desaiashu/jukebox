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
// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


struct PlaylistSong: Equatable {
    var yt_id: String
    var title: String
    var artist: String
    var item: AVPlayerItem?
    var duration: Int
}
func ==(lhs: PlaylistSong, rhs: PlaylistSong) -> Bool {
    return lhs.yt_id == rhs.yt_id
}
func playlistSongFromInboxSong(_ song: InboxSong)->PlaylistSong {
    return PlaylistSong(yt_id: song.yt_id, title: song.title, artist: song.artist, item: nil, duration: 0)
}

class SongPlayer : NSObject{
    static let songPlayer = SongPlayer()
    
    weak var playerButton: UIButton!
    weak var artistLabel: UILabel!
    weak var titleLabel: UILabel!
    weak var skipButton: UIButton!
    weak var progressBar: UIProgressView!
    weak var loadingIndicator: UIActivityIndicatorView!
    
    var periodicTimeObserver: AnyObject?
    var player = AVQueuePlayer() //Actual audio player
    
    var playlist: [PlaylistSong] = []
    var loadeditems = 0
    var currentSongIndex = 0
    var timePlayed = 0
    
    var buffering = false
    
    func setup(_ playerButton: UIButton, artistLabel: UILabel, titleLabel: UILabel, skipButton: UIButton, progressBar: UIProgressView, loadingIndicator: UIActivityIndicatorView) {
        
        self.playerButton = playerButton
        self.artistLabel = artistLabel
        self.titleLabel = titleLabel
        self.skipButton = skipButton
        self.progressBar = progressBar
        self.loadingIndicator = loadingIndicator
        
//        self.playerButton.setTitleColor(UIColor.lightGray, for: UIControlState.disabled)
//        self.playerButton.setTitle("...", for: UIControlState.disabled)
//        self.skipButton.setTitleColor(UIColor.lightGray, for: UIControlState.disabled)
        
        do {
            try AVAudioSession.sharedInstance().setCategoryconvertFromAVAudioSessionCategory(AVAudioSession.Category.playback)
        } catch _ {
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch _ {
        }
        UIApplication.shared.beginReceivingRemoteControlEvents()
        
        periodicTimeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: DispatchQueue.main) { cmTime in
            self.timeObserverFired(cmTime)
        } as AnyObject?
        
        self.createPlaylist(nil)
    }
    
    func timeObserverFired(_ cmTime: CMTime) {
        
        if player.currentTime().timescale == 0 {
            self.timePlayed = 0
        } else {
            self.timePlayed = Int(Double(player.currentTime().value)/Double(player.currentTime().timescale))
        }
        
        if self.timePlayed == 1 { // Once song starts playing
            self.beganPlaying()
        }

        if self.timePlayed == self.playlist[self.currentSongIndex].duration {
            self.nextSong()
        } else {
            self.updateMediaPlayer()
        }

        // TODO: Buffering in middle of song 
        // If in .1 seconds timeplayed hasn't changed, and the rate is 1.0, buffering = true?
    }
    
    func createPlaylist(_ startingSong:PlaylistSong?) {
        
        self.player.pause()
        self.player.removeAllItems()
        self.loadeditems = 0
        self.currentSongIndex = 0
        self.timePlayed = 0
        
        if let song = startingSong {
            self.playlist = [song]
        } else {
            self.playlist = []
            self.playerButton.setImage(#imageLiteral(resourceName: "play_purple"), for: UIControl.State())
        }
        
        let newInboxSongs = realm.objects(InboxSong.self).filter("listen == false AND mute == false AND recipient == %@", User.user.phoneNumber).sorted(byKeyPath: "date", ascending: false)
        self.playlist = newInboxSongs.reduce(self.playlist) { $0 +
            ( !$0.contains(playlistSongFromInboxSong($1))
                ? [playlistSongFromInboxSong($1)] : [] ) }
        
        let oldInboxSongs = realm.objects(InboxSong.self).filter("listen == true AND mute == false").sorted(byKeyPath: "date", ascending: false)
        var oldSongs = oldInboxSongs.reduce([]) { $0 +
                (!self.playlist.contains(playlistSongFromInboxSong($1)) &&
                    !$0.contains(playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }
        
        oldSongs.shuffle()
        self.playlist = self.playlist + oldSongs
        
        if self.playlist.count > 0 {
            self.getStreamUrl(self.playlist[loadeditems].yt_id)
            self.setNowPlaying()
        }
    }
    
    func getStreamUrl(_ yt_id: String) {
        
        if let urlString = UserDefaults.standard.object(forKey: yt_id) as? String {
            let expireRange = urlString.range(of: "expire=")
            let range = urlString.index(expireRange!.lowerBound, offsetBy: 7)...urlString.index(expireRange!.lowerBound, offsetBy: 16)
            let expiration = urlString[range]
            let expirationInt = Int(expiration)
            let currentTime = Int(Date().timeIntervalSince1970)+3600 //Give some buffer
            if expirationInt > currentTime {
                let duration = (UserDefaults.standard.object(forKey: yt_id+".duration") as? Int ?? 0)
                self.createPlayerItem(URL(string: urlString)!, duration: duration)
                return //No need to download stuffs
            }
        }
        
        XCDYouTubeClient.default().getVideoWithIdentifier(yt_id, completionHandler: { video, error in
            if self.loadeditems >= self.playlist.count {
                return //If you play a new song mid loading the stream, whichever song was loading will call the completionHandler
            }
            if let error = error as? NSError {
                if error.domain == XCDYouTubeVideoErrorDomain {
                    if error.code == XCDYouTubeErrorCode.restrictedPlayback.rawValue {
                        let objectsToDelete = realm.objects(InboxSong.self).filter("yt_id == %@", yt_id)
                        try! realm.write(){
                            realm.delete(objectsToDelete)
                        }
                        self.playlist.remove(at: self.loadeditems)  //TODO
                        print("this might happen once, but it shouldn't break anything")
                        let navigationController = UIApplication.shared.keyWindow?.rootViewController as! UINavigationController
                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
                            inboxViewController.tableView.reloadData()
                        }
                        if self.loadeditems < self.playlist.count {
                            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
                        }
                    }
                }
            } else if let video = video {
                //Audio only is video.streamURLs[140]
                if let url = video.streamURLs[NSNumber(value: 140)] {
                    UserDefaults.standard.set(url.absoluteString, forKey: video.identifier)
                    UserDefaults.standard.set(Int(video.duration), forKey: video.identifier+".duration")
                    if self.playlist[self.loadeditems].yt_id == video.identifier {
                        self.createPlayerItem(url, duration: Int(video.duration))
                        return //Since every thing else needs to get next streamUrl
                    } else {
                        print("out of sync, likely playlist changed")
                    }
                }
            }
        })
    }
    
    func createPlayerItem(_ url: URL, duration: Int) {
        let playerItem = AVPlayerItem(url: url)
        self.playlist[self.loadeditems].item = playerItem
        self.playlist[self.loadeditems].duration = duration
        self.player.insert(playerItem, after: nil)
        
        if self.loadeditems == 0 && self.titleLabel.text != self.playlist[self.loadeditems].title {
            self.setNowPlaying() //Covers case where deleted song happened to be chosen first
        }
        
        self.loadeditems += 1
        if self.loadeditems-1 == self.currentSongIndex && !self.playerButton.isEnabled {
            self.playerButton.isEnabled = true
            self.triggerListen()
        }
        
        if self.loadeditems < self.playlist.count {
            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
        }
    }
    
    func updatePlaylist() {
        if self.playlist.count != 0 { //Off chance inbox hasn't downloaded when you first login
            let unloaded = self.playlist.count - self.loadeditems
            
            let newInboxSongs = realm.objects(InboxSong.self).filter("mute == false").sorted(byKeyPath: "date")
            self.playlist = newInboxSongs.reduce(self.playlist) { $0 +
                (!self.playlist.contains(playlistSongFromInboxSong($1)) &&
                    !$0.contains(playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }

            if unloaded == 0 && self.loadeditems < self.playlist.count { //Load new songs
                self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
            }
        }
    }
    
    //When play on cell tapped
    func play(_ yt_id: String, title: String, artist: String) {
        self.createPlaylist(PlaylistSong(yt_id: yt_id, title: title, artist: artist, item: nil, duration: 0))
        self.play()
    }
    
    func playerButtonPressed() {
        if self.playerButton.currentImage == #imageLiteral(resourceName: "play_purple") {
            self.play()
        } else {
            self.pause()
        }
    }
    
    func play() {
        if self.loadeditems == 0 {
            self.playerButton.isEnabled = false
        }
        self.player.play()
        self.playerButton.setImage(#imageLiteral(resourceName: "pause_purple"), for: UIControl.State())
        
        if self.timePlayed == 0 {
            self.buffering = true
            self.playerButton.isEnabled = false
            //TODO start animation
            self.loadingIndicator.startAnimating()
        }
    }
    
    func beganPlaying() {
        self.triggerListen() // This needs to go here to ensure it's not called if a song doesn't actually play
        
        buffering = false
        self.playerButton.isEnabled = true
        //TODO stop animation
        self.loadingIndicator.stopAnimating()
        
//        if AVAudioSession.sharedInstance().category == AVAudioSessionCategoryAmbient { //This might happen a second too late and have overlap
//            do {
//                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
//            } catch _ {
//            }
//            do {
//                try AVAudioSession.sharedInstance().setActive(true)
//            } catch _ {
//            }
//            UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
//        }
    }
    
    func pause() {
        self.player.pause()
        self.playerButton.setImage(#imageLiteral(resourceName: "play_purple"), for: UIControl.State())
        
        self.buffering = false
        self.playerButton.isEnabled = true
        //TODO stop animation
        self.loadingIndicator.stopAnimating()
        
//        if AVAudioSession.sharedInstance().category == AVAudioSessionCategoryPlayback {
//            //Reset back to ambient so if someone leaves app and plays song on spotify they can return and keep listening
//            do {
//                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryAmbient)
//            } catch _ {
//            }
//            do {
//                try AVAudioSession.sharedInstance().setActive(true)
//            } catch _ {
//            }
//            UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
//        }
    }
    
    func skip() {
        if self.playerButton.isEnabled { //Protecting against the "loading" case
            self.nextSong()
            self.skipButton.isEnabled = false //Protecting against hammering on skip button
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
                self.skipButton.isEnabled = true
            }
        }
    }
    
    func nextSong() {
        self.currentSongIndex += 1
        self.player.advanceToNextItem()
        if currentSongIndex >= self.playlist.count {
            self.createPlaylist(nil)
        } else {
            self.timePlayed = 0
            self.setNowPlaying()
            if self.loadeditems < self.currentSongIndex { //If url hasn't loaded for next song
                print("not yet loaded")
                self.playerButton.isEnabled = false
                self.getStreamUrl(self.playlist[currentSongIndex].yt_id)
            } else {
                if self.player.rate == 1.0 {
                    self.triggerListen()
                }
            }
        }
    }
    
    func remoteControlReceivedWithEvent(_ event: UIEvent?) {
        if let event = event {
            if event.type == UIEvent.EventType.remoteControl {
                if event.subtype == UIEvent.EventSubtype.remoteControlPlay {
                    self.play()
                } else if event.subtype == UIEvent.EventSubtype.remoteControlPause {
                    self.pause()
                } else if event.subtype == UIEvent.EventSubtype.remoteControlNextTrack {
                    self.skip()
                } //TODO, handle going previous track
            }
        }
    }
    
    func toggleMute(_ yt_id: String, title: String, artist: String, mute: Bool) {
        if mute {
            self.mute(yt_id, title: title, artist: artist)
        } else {
            self.unmute(yt_id, title: title, artist: artist)
        }
    }
    
    func mute(_ yt_id: String, title: String, artist: String) {
        //If mute, remove songs from playlist IF song is after current index
        //      If song removed is next index, set identifier for second player (unless no songs left)
        if let index = self.playlist.firstIndex(of: PlaylistSong(yt_id: yt_id, title: title, artist: artist, item: nil, duration: 0)) {
            if index != loadeditems { //If it's currently loading, it will break stuff
                if index == self.currentSongIndex {
                    //self.skip() //This isn't working properly so leaving it in the playlist for now (#muteskip)
                } else if index > self.currentSongIndex {
                    let playlistSong = self.playlist.remove(at: index)
                    self.player.remove(playlistSong.item!)
                    loadeditems -= 1
                }
            }
        }
    }
    
    func unmute(_ yt_id: String, title: String, artist: String) {
        //If unmute, add song to end of playlist
        self.playlist.append(PlaylistSong(yt_id: yt_id, title: title, artist: artist, item:nil, duration: 0))
        if self.loadeditems == self.playlist.count-1 {
            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
        }
    }
    
    func setNowPlaying() {
        let playlistSong = self.playlist[currentSongIndex]
        self.titleLabel.text = playlistSong.title
        self.artistLabel.text = playlistSong.artist
        self.updateMediaPlayer()
    }
    
    func updateMediaPlayer() {
        let playlistSong = self.playlist[currentSongIndex]
        let image:UIImage = UIImage(named: "jukebox")!
        let albumArt = MPMediaItemArtwork(image: image)
        let songInfo: [String: Any] = [
            MPMediaItemPropertyTitle: playlistSong.title,
            MPMediaItemPropertyArtist: playlistSong.artist,
            MPMediaItemPropertyArtwork: albumArt,
            MPMediaItemPropertyPlaybackDuration: playlistSong.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: self.timePlayed
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = songInfo
        
        self.progressBar.setProgress(Float(self.timePlayed)/Float(playlistSong.duration), animated: true)
    }
    
    func triggerListen() {
        let yt_id = self.playlist[currentSongIndex].yt_id
        //Note, listen is set to true even if user listens to same song via search, or same song sent by other friend
        for sameSong in realm.objects(InboxSong.self).filter("yt_id == %@ AND recipient == %@", yt_id, User.user.phoneNumber)
        {
            sameSong.hear()
        }
        let navigationController = UIApplication.shared.keyWindow?.rootViewController as! UINavigationController
        if let inboxViewController = navigationController.topViewController as? InboxViewController {
            inboxViewController.tableView.reloadData()
        }
    }
}


//extension MutableCollection where Index == Int, IndexDistance == Int {
//    /// Shuffle the elements of `self` in-place.
//    mutating func shuffle() {
//        // empty and single-element collections don't shuffle
//        if count < 2 { return }
//
//        for i in 0..<count - 1 {
//            let j = Int(arc4random_uniform(UInt32(count - i))) + i
//            guard i != j else { continue }
//            self.swapAt(i, j)
//        }
//    }
//}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
