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

//Playlist song is a struct that's stored in the array of songs
struct PlaylistSong: Equatable {
    var yt_id: String
    var title: String
    var artist: String
    var item: AVPlayerItem?
}
func ==(lhs: PlaylistSong, rhs: PlaylistSong) -> Bool { //This function lets you test equality between two PlaylistSong items based on youtube ID
    return lhs.yt_id == rhs.yt_id
}
func playlistSongFromInboxSong(song: InboxSong)->PlaylistSong { //This function converts an InboxSong to PlaylistSong (you likely won't need)
    return PlaylistSong(yt_id: song.yt_id, title: song.title, artist: song.artist, item:nil)
}

class SongPlayer : NSObject{
    //Initialize self as a singleton to be called from external files
    static let songPlayer = SongPlayer()
    
    //Controls + display of my music player widget
    weak var playerButton: UIButton!
    weak var artistLabel: UILabel!
    weak var titleLabel: UILabel!
    weak var skipButton: UIButton!
    
    var player = AVQueuePlayer() //Actual audio player
    
    var playlist: [PlaylistSong] = [] //Array of songs that makes up the playlist
    var loadeditems = 0 //Index of songs that have their URLs loaded (remember loading URLs is separate from buffering)
    var currentSongIndex = 0 //Index of currently playing song
    
    func setup(playerButton: UIButton, artistLabel: UILabel, titleLabel: UILabel, skipButton: UIButton) {
        
        //Setup UI elements
        self.playerButton = playerButton
        self.artistLabel = artistLabel
        self.titleLabel = titleLabel
        self.skipButton = skipButton
        
        self.playerButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        self.playerButton.setTitle("...", forState: UIControlState.Disabled)
        self.skipButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        
        //Enable background playback
        AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error:nil)
        AVAudioSession.sharedInstance().setActive(true, error: nil)
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        
        //Create playlist when class is first loaded
        self.createPlaylist(nil)
    }
    
    //Create playlist method creates a new playlist. If you pass in a PlaylistSong, that's guaranteed to be the first song, otherwise I randomly generate order for the playlist
    func createPlaylist(startingSong:PlaylistSong?) {
        
        //Since this is also called when the playlist is finished playing, reset all playlist variables
        player.pause()
        player.removeAllItems()
        self.loadeditems = 0
        self.currentSongIndex = 0
        
        if var song = startingSong {
            self.playlist = [song] //If we've been passed in a starting song, set it as the first item in playlist (you probably won't need this)
        } else {
            self.playlist = [] //Otherwise start from scratch
            self.playerButton.setTitle("Play", forState: UIControlState.Normal)
        }
        
        //I pull items from my database based on which songs you haven't listened to. newInboxSongs is essentially "unread" items, I put them at the start of the playlist
        let newInboxSongs = realm.objects(InboxSong).filter("listen == false AND mute == false AND recipient == %@", User.user.phoneNumber).sorted("date", ascending: false)
        self.playlist = reduce(newInboxSongs, self.playlist) { $0 +
            ( !contains($0, playlistSongFromInboxSong($1))
                ? [playlistSongFromInboxSong($1)] : [] ) }
        
        //Then I randomize the remaining songs in my inbox
        let oldInboxSongs = realm.objects(InboxSong).filter("listen == true AND mute == false").sorted("date", ascending: false)
        let oldSongs = reduce(oldInboxSongs, []) { $0 +
                (!contains(self.playlist, playlistSongFromInboxSong($1)) &&
                    !contains($0, playlistSongFromInboxSong($1))
                    ? [playlistSongFromInboxSong($1)] : [] ) }
        
        //Add them together to get the final playlist. You should replace all this with your own playlist
        self.playlist = self.playlist + self.shuffle(oldSongs)

        //If the playlist is longer than 0 songs, load the first item
        if self.playlist.count > 0 {
            self.getStreamUrl(self.playlist[loadeditems].yt_id)
            //Also update the UI elements with the current song
            self.setNowPlaying()
        }
    }
    
    //Downloads the youtube stream URL based on songID, remember this is different than buffering but needs to be done
    func getStreamUrl(yt_id: String) {
        
        //First check if the URL is cached in NSUserDefaults
        if let urlString = NSUserDefaults.standardUserDefaults().objectForKey(yt_id) as? String {
            var expireRange = urlString.rangeOfString("expire=")
            var range = advance(expireRange!.startIndex, 7)...advance(expireRange!.startIndex, 16)
            var expiration = urlString[range]
            var expirationInt = expiration.toInt()
            var currentTime = Int(NSDate().timeIntervalSince1970)+3600 //Give 1hr buffer for expiration date
            if expirationInt > currentTime { //If it's cached and not expired, no need to download, just createPlayerItem
                self.createPlayerItem(NSURL(string: urlString)!)
                return //No need to download stuffs
            }
        }
        
        //If it wasn't cached, or cache was expired, download the url from XCDYoutubeClient
        XCDYouTubeClient.defaultClient().getVideoWithIdentifier(yt_id, completionHandler: { video, error in
            if self.loadeditems >= self.playlist.count {
                return //If you start creating a new playlist before the first playlist was finished loading the URLs, you run into race conditions, this if helps kill the original playlist loading
            }
            if let e = error {
                //If there was an error with URL downloading
                if error.domain == XCDYouTubeVideoErrorDomain {
                    //Specifically if the error was restricted playback, we should delete the song from the playlist, and ideally from the database/server because we'll never be able to play it again
                    if error.code == XCDYouTubeErrorCode.RestrictedPlayback.rawValue {
                        var objectsToDelete = realm.objects(InboxSong).filter("yt_id == %@", yt_id)
                        realm.write(){
                            realm.delete(objectsToDelete)
                        }
                        self.playlist.removeAtIndex(self.loadeditems)  //TODO
                        println("this will happen once, but it shouldn't break anything")
                        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
                            inboxViewController.tableView.reloadData()
                        }
                        //After deleting the song from the playlist, I load the next song. The next song now has index self.loadeditems since we just deleted the object at index self.loadeditems
                        if self.loadeditems < self.playlist.count {
                            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
                        }
                    }
                    //If the error was something else, I'm currently not handling this properly. It would likely be a network error so it looks like I just stop trying to load songs
                }
            } else {
                //If the url was loaded successfully, grab the streamURL we want (by default an array of streams corresponding to different formats is downloaded
                //Audio only is video.streamURLs[140] but causes delay in notification
                if let url = video.streamURLs[XCDYouTubeVideoQuality.Small240.rawValue] as? NSURL {
                    //Store the streamURL in NSUserDefaults
                    NSUserDefaults.standardUserDefaults().setObject(url.absoluteString!, forKey: video.identifier)
                    if self.playlist[self.loadeditems].yt_id == video.identifier {
                        //If the video indentifier corresponds to the song at index self.loadeditems in the playlist, create player item
                        self.createPlayerItem(url)
                        return //Since every thing else needs to get next streamUrl
                    } else {
                        //The video identifier may not correspond because we created a new playlist in the middle of loading the first (you probably don't need to worry about this)
                        println("out of sync, likely playlist changed")
                    }
                }
            }
        })
    }
    
    //Create player item creates the AVPlayerItem for each song
    func createPlayerItem(url: NSURL) {
        //Create the AVPlayerItem
        var playerItem = AVPlayerItem(URL: url)
        //Store a reference to it in self.loadeditems (I'm not sure I use the reference too much, but figured it'd be good to have)
        self.playlist[self.loadeditems].item = playerItem
        //Add a notification handler for when the AVPlayerItem is finished playing. This is important to increment the currentSong index as well as update the UI to show the new song
        NSNotificationCenter.defaultCenter().addObserverForName(AVPlayerItemDidPlayToEndTimeNotification, object: playerItem, queue: NSOperationQueue.mainQueue(), usingBlock: { notification in
            self.nextSong()
        })
        //Insert the playerItem we created at the end of the AVQueuePlayer (essentially at the end of the playlist)
        self.player.insertItem(playerItem, afterItem: nil)
        
        //In case the first song in the playlist was the deleted song (due to youtube error), and the player widget showed the title/artist of the deleted song, we need to update it
        if self.loadeditems == 0 && self.titleLabel.text != self.playlist[self.loadeditems].title {
            self.setNowPlaying() //Covers case where deleted song happened to be chosen first
        }
        
        //Increment loaded items
        self.loadeditems++
        //If the song was played but URL hadn't been loaded yet, I disable some of the UI buttons and show "..." in place of the play button. This simply reverts that
        if self.loadeditems-1 == self.currentSongIndex && !self.playerButton.enabled {
            self.playerButton.enabled = true
            self.triggerListen() //Trigger listen is just to tell the server I've "read" a song (you probably don't need to worry about this)
        }
        
        //If not all songs have been loaded yet, load the next song!
        if self.loadeditems < self.playlist.count {
            self.getStreamUrl(self.playlist[self.loadeditems].yt_id)
        }
    }
    
    //Update playlist adds new songs the server just sent me to the playlist (you probably don't have to worry about this)
    func updatePlaylist() {
        if self.playlist.count != 0 { //Off chance inbox hasn't downloaded when you first login
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
    
    //When play button on a specific song cell is tapped, I recreate the playlist with that song at the start (you may not have to worry about this). This is responsible for all the interrupts and race conditions I was mentioning.
    func play(yt_id: String, title: String, artist: String) {
        self.createPlaylist(PlaylistSong(yt_id: yt_id, title: title, artist: artist, item: nil))
        self.play()
    }
    
    //When the play/pause button on the player widget is pressed
    func playerButtonPressed() {
        if self.playerButton.titleLabel?.text == "Play" {
            self.play()
        } else {
            self.pause()
        }
    }
    
    //When play is pressed
    func play() {
        //If no items have been loaded yet, show "..." instead of the pause button
        if self.loadeditems == 0 {
            self.playerButton.enabled = false
        } else { //Otherwise tell server I've "listened" to the song
            self.triggerListen()
        }
        //Play the AVQueuePlayer and set player button to show "pause"
        self.player.play()
        self.playerButton.setTitle("Pause", forState: UIControlState.Normal)
    }
    
    //When pause is pressed, pause the AVQueuePlayer and set player button to show "play"
    func pause() {
        self.player.pause()
        self.playerButton.setTitle("Play", forState: UIControlState.Normal)
    }
    
    //When skip is pressed
    func skip() {
        if self.playerButton.enabled { //Protecting against the case when the player is still "loading" urls
            //Advance the AVQueuePlayer to the next item
            self.player.advanceToNextItem()
            //Update variables relevant to moving to the next song (see method)
            self.nextSong()
            //Temporarily disable skip bc I had problems when user mashed the skip button
            self.skipButton.enabled = false //Protecting against hammering on skip button
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
                self.skipButton.enabled = true
            }
        }
    }
    
    //This function updates variables relevant to moving to the next song. It's called when a song naturally ends, as well as when the user manually skips a song.
    func nextSong() {
        //Increment current song index.
        self.currentSongIndex++
        //If you're at the end of the playlist, create a new playlist (which also pauses the AVQueuePlayer)
        if currentSongIndex >= self.playlist.count {
            self.createPlaylist(nil)
        } else {
            //Otherwise, update the UI to reflect teh next song
            self.setNowPlaying()
            if self.loadeditems < self.currentSongIndex { //If url hasn't loaded for next song, show "..." instead of pause button
                self.playerButton.enabled = false
            } else {
                if self.player.rate == 1.0 { //If the player is playing, trigger the listen call to server for the new song
                    self.triggerListen()
                }
            }
        }
    }
    
    //Respond to notifications from the lock screen music player (note, this method is called by the equivalent method in the AppDelegate, so refer to that as well)
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
    
    //Muting allows a user to stop a song from playing as part of the playlist (you probably won't need this so I won't go into detail)
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
    
    //Updates UI for the song that's now playing (or if playlist is first created the first song that would play
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
    
    //Sends info to server (you won't need this)
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
    
    //Shuffle is called by createPlaylist to help randomize the playlist order
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