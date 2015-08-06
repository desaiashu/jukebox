//
//  SongPlayer.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import XCDYouTubeKit

class SongPlayer {
    
    static var videoPlayerController: XCDYouTubeVideoPlayerViewController?
    
    class func play(videoIdentifier: String) {
        
        if let playerController = videoPlayerController, let player = playerController.moviePlayer{
            player.stop()
        }
        
        videoPlayerController = XCDYouTubeVideoPlayerViewController(videoIdentifier: videoIdentifier)
        videoPlayerController!.preferredVideoQualities = [XCDYouTubeVideoQuality.Small240.rawValue]
        videoPlayerController!.moviePlayer.play()
        
        //Need to do background playback
    }
    
    class func stop() {
        if let playerController = videoPlayerController, let player = playerController.moviePlayer{
            player.stop()
        }
    }
}