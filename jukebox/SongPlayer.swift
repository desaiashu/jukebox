//
//  SongPlayer.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import XCDYouTubeKit
import AVFoundation

class SongPlayer {
    
    static var videoPlayerController: XCDYouTubeVideoPlayerViewController?
    
    class func enableBackgroundAudio () {
        var success1 = AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, error:nil)
        var success2 = AVAudioSession.sharedInstance().setActive(true, error: nil)
    }
    
    class func play(videoIdentifier: String) {
        
        if let playerController = videoPlayerController, let player = playerController.moviePlayer{
            player.stop()
        }
        
        videoPlayerController = XCDYouTubeVideoPlayerViewController(videoIdentifier: videoIdentifier)
        videoPlayerController!.preferredVideoQualities = [XCDYouTubeVideoQuality.Small240.rawValue]
        videoPlayerController?.moviePlayer.backgroundPlaybackEnabled = true
        videoPlayerController!.moviePlayer.play()
    }
    
    class func stop() {
        if let playerController = videoPlayerController, let player = playerController.moviePlayer{
            player.stop()
        }
    }
}