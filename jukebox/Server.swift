//
//  Server.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/5/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import Alamofire
import Crashlytics
import UIKit

struct k {
    static let server_url = "http://192.168.1.7:5000/"
    static let youtube_url = "https://www.googleapis.com/youtube/v3/search?key=AIzaSyBK4c6lUvrKyH3rt3dbsSS-jUVPDjRGyT0&part=snippet&type=video&videoCategoryId=10&order=relevance&maxResults=50&fields=items(id(videoId)%2Csnippet(title))&q="
}

class Server {
    
    class func checkVersion() {
        Alamofire.request(.POST, k.server_url+"confirm", parameters: ["phone_number":User.user.phoneNumber], encoding: .JSON)
            .responseJSON { request, response, json, error in
                println(json)
                if let result = json as? [String:AnyObject?] {
                    let latestVersion = result["version"]! as! String
                    let currentVersion = NSBundle.mainBundle().objectForInfoDictionaryKey(kCFBundleVersionKey as String) as! String
                    if currentVersion.compare(latestVersion, options:NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedAscending {
                        let forced = result["forced"]! as! Bool
                        let url = result["url"]! as! String
                        self.promptUserToUpdate(forced, url: url)
                    }
                }
        }
    }
    
    class func promptUserToUpdate(forced: Bool, url: String) {
        var title: String?
        var message: String?
        if forced {
            title = "Update Required"
            message = "You must update the app to continue using, tap update to download"
        } else {
            title = "Update Available"
            message = "A new update is available, tap update to download"
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        if !forced {
            alertController.addAction(UIAlertAction(title: "Later", style: UIAlertActionStyle.Cancel, handler:nil))
        }
        alertController.addAction(
            UIAlertAction(title: "Update", style: UIAlertActionStyle.Default, handler: { UIAlertAction in
                UIApplication.sharedApplication().openURL(NSURL(string: url)!)
            })
        )
        UIApplication.sharedApplication().keyWindow?.rootViewController?.presentViewController(alertController, animated: true, completion: nil)
    }
    
    class func registerUser(callback: (Bool)->Void) {
        Alamofire.request(.POST, k.server_url+"confirm", parameters: ["phone_number":User.user.phoneNumber], encoding: .JSON)
            .responseJSON { request, response, json, error in
                println(json)
                if let result = json as? [String:Bool] {
                    let success = result["success"]!
                    if success {
                        Answers.logCustomEventWithName("Register", customAttributes:nil)
                    }
                    callback(success)
                } else {
                    callback(false)
                }
        }
    }
    
    class func authenticateUser(callback: (Bool)->Void) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"confirm", parameters: ["phone_number":user.phoneNumber, "code":user.code], encoding: .JSON)
            .responseJSON { request, response, json, error in
                println(json)
                if let result = json as? [String:Bool] {
                    let success = result["success"]!
                    if success {
                        Answers.logCustomEventWithName("Authenticate", customAttributes:nil)
                    }
                    callback(success)
                } else {
                    callback(false)
                }
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
                                var createdSong = realm.create(InboxSong.self, value: song, update: true)
                                
                                var incoming = true
                                var friendNumber = song["sender"]! as! String
                                if friendNumber == user.phoneNumber {
                                    friendNumber = song["recipient"]! as! String
                                    incoming = false
                                    createdSong.listen = true
                                }
                                var friend = realm.objects(Friend).filter("phoneNumber == %@", friendNumber).first
                                
                                var shareDate = song["date"]! as! Int
                                if shareDate > friend?.lastShared {
                                    friend?.lastShared = shareDate
                                }
                                if user.lastUpdated == 0 || incoming {
                                    friend?.numShared++
                                }
                            }
                            user.lastUpdated = Int(NSDate().timeIntervalSince1970)
                            callback()
                        }
                    }
                }
        }
    }
    
    //Might want to resend these if it fails the first time
    class func listen(song: InboxSong) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"listen", parameters: ["phone_number":user.phoneNumber, "code":user.code, "id":song.id, "title":song.title, "artist":song.artist, "sender_name":user.firstName], encoding: .JSON)
        Answers.logCustomEventWithName("Listen", customAttributes: nil)
    }
    
    class func love(song: InboxSong) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"love", parameters: ["phone_number":user.phoneNumber, "code":user.code, "id":song.id, "title":song.title, "artist":song.artist, "sender_name":user.firstName], encoding: .JSON)
        Answers.logCustomEventWithName("Love", customAttributes: nil)
    }
    
    class func cacheSong(song: SendSong) {
        let now = Int(NSDate().timeIntervalSince1970)
        song.date = now
        realm.write() {
            realm.add(song)
            
            var recipients = split(song.recipients) {$0 == ","}
            for recipient in recipients {
                var inboxSong = InboxSong()
                
                inboxSong.title = song.title
                inboxSong.artist = song.artist
                inboxSong.yt_id = song.yt_id
                inboxSong.sender = User.user.phoneNumber
                inboxSong.recipient = recipient
                inboxSong.date = song.date
                inboxSong.updated = song.date
                inboxSong.id = String(song.date)+recipient
                
                realm.add(inboxSong)
                
                var friend = realm.objects(Friend).filter("phoneNumber == %@", recipient).first
                friend?.lastShared = song.date
                friend?.numShared++
            }
        }
        Answers.logCustomEventWithName("Share", customAttributes: nil)
    }
    
    class func sendSongs() {
        
        let user = User.user
        let unsentSongs = realm.objects(SendSong)
        for song in unsentSongs {
            
            let params: [String:AnyObject] = ["phone_number": user.phoneNumber, "code": user.code, "title":song.title, "artist":song.artist, "yt_id":song.yt_id, "date":song.date, "updated":song.date, "recipients":song.recipients, "sender_name":user.firstName]
            Alamofire.request(.POST, k.server_url+"share", parameters: params, encoding: .JSON)
                .responseJSON { request, response, json, error in
                    println(json)
                    if let result = json as? [String:[[String:AnyObject]]] {
                        if let songs = result["songs"] {
                            realm.write() {
                                for downloadedSong in songs {
                                    //Save new copy w/ id from server
                                    var createdSong = realm.create(InboxSong.self, value: downloadedSong, update: true)
                                    createdSong.listen = true
                                    
                                    //Delete old copy w/ old id
                                    let old_id = String(song.date)+(downloadedSong["recipient"]! as! String)
                                    if let inboxSong = realm.objects(InboxSong).filter("id == %@", old_id).first {
                                        realm.delete(inboxSong)
                                    }
                                }
                                //Delete SendSong
                                realm.delete(song)
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
            
            let startIndexOfDash = newString.rangeOfString(" - ")?.startIndex
            let endIndexOfDash = newString.rangeOfString(" - ")?.endIndex
            let artist = newString.substringToIndex(startIndexOfDash!).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " \""))
            let title = newString.substringFromIndex(endIndexOfDash!).stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: " \""))
            
            return ["artist":artist, "title":title];
            
        } else {
            return nil
        }
        
    }
}
