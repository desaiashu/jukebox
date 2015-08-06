//
//  Server.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/5/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import Alamofire

struct k {
    static let server_url = "http://192.168.1.7:5000/"
    static let youtube_url = "https://www.googleapis.com/youtube/v3/search?key=AIzaSyBK4c6lUvrKyH3rt3dbsSS-jUVPDjRGyT0&part=snippet&type=video&videoCategoryId=10&order=relevance&maxResults=50&fields=items(id(videoId)%2Csnippet(title))&q="
}

class Server {
    
    class func registerUser(callback: ()->Void) {
        Alamofire.request(.POST, k.server_url+"confirm", parameters: ["phone_number":User.user.phoneNumber], encoding: .JSON)
    }
    
    class func authenticateUser(callback: ()->Void) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"confirm", parameters: ["phone_number":user.phoneNumber, "code":user.code], encoding: .JSON)
            .responseJSON { request, response, json, error in
                println(json)
        }
    }
    
    class func sendPushToken() {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"pushtoken", parameters: ["phone_number":user.phoneNumber, "code":user.code, "push_token":user.pushToken], encoding: .JSON)
    }
    
    class func downloadInbox(callback: ()->Void) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"inbox", parameters: ["phone_number": user.phoneNumber, "code":user.code, "last_updated":user.lastUpdated], encoding: .JSON)
            .responseJSON { request, response, json, error in
                println(json)
                if let result = json as? [String:[[String:AnyObject]]] {
                    if let inbox = result["inbox"] {
                        realm.write() {
                            for song in inbox {
                                realm.create(InboxSong.self, value: song, update: true)
                            }
                            user.lastUpdated = Int(NSDate().timeIntervalSince1970)
                            callback()
                        }
                    }
                }
        }
    }
    
    class func sendSongs() {
        
        let user = User.user
        let unsentSongs = realm.objects(SendSong)
        for song in unsentSongs {
            
            let params: [String:AnyObject] = ["phone_number": user.phoneNumber, "code": user.code, "title":song.title, "artist":song.artist, "yt_id":song.yt_id, "date":song.date, "updated":song.date, "recipients":song.recipients, "sender_name":user.firstName]
            Alamofire.request(.POST, k.server_url+"share", parameters: params, encoding: .JSON)
                .responseJSON { request, response, json, error in
                    println(json)
                    if let result = json as? [String:Bool] {
                        if let success = result["result"] {
                            if success {
                                realm.write() {
                                    realm.delete(song)
                                }
                            }
                        }
                    }
            }
        }
    }
    
    class func searchSong(query: String, callback: [SendSong]->Void) {
        if let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet()) {
            Alamofire.request(.GET, k.youtube_url+escapedQuery)
                .responseJSON { request, response, json, error in
                    if let result = json as? [String:[[String:[String:String]]]] {
                        if let items = result["items"] {
                            
                            let tempResults = self.parseResults(items)
                            callback(tempResults)
                        }
                    }
            }
        }
    }
    
    class func parseResults(items: [[String:[String:String]]]) -> [SendSong] {
        
        //TODO: Make this smarter, eliminate duplicates + crap results, cross relevance + view count?
        var tempResults: [SendSong] = []
        for item in items {
            let songString = item["snippet"]!["title"]!
            
            if let titleAndArtist = getTitleAndArtist(songString) {
                var song = SendSong()
                song.title = titleAndArtist["title"]!
                song.artist = titleAndArtist["artist"]!
                song.yt_id = item["id"]!["videoId"]!
                tempResults.append(song)
            }
        }
        return tempResults
    }
    
    class func getTitleAndArtist(songString: String) ->[String:String]? {
        if let indexOfDash = songString.rangeOfString(" - ")?.startIndex {
            var newString = songString
            
            let stringsToRemove = ["Official Music Video","Official Music Video","Official Video","Official Audio","Video Official","Lyric Video","Audio Only","Lyrics","Official Cover Video","VEVO Presents","Full Lyric Video","Explicit","On Screen","[]","[ ]","()","( )"]
            for string in stringsToRemove {
                newString = newString.stringByReplacingOccurrencesOfString(string, withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            }
            
            let startIndexOfDash = songString.rangeOfString(" - ")?.startIndex
            let endIndexOfDash = songString.rangeOfString(" - ")?.endIndex
            let artist = songString.substringToIndex(startIndexOfDash!).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " \""))
            let title = newString.substringFromIndex(endIndexOfDash!).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " \""))
            
            return ["artist":artist, "title":title];
            
        } else {
            return nil
        }
        
    }
}
