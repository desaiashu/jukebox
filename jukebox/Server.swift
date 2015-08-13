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
    static let server_url = "https://www.jkbx.es/"
    static let youtube_url = "https://www.googleapis.com/youtube/v3/search?key=AIzaSyBK4c6lUvrKyH3rt3dbsSS-jUVPDjRGyT0&part=snippet&type=video&videoCategoryId=10&order=relevance&maxResults=50&fields=items(id(videoId)%2Csnippet(title))&q="
}

class Server {
    static let server = Server()
    
    func checkVersion() {
        Alamofire.request(.GET, k.server_url+"version")
            .responseJSON { request, response, json, error in
                if let result = json as? [String:AnyObject] {
                    let latestVersion = result["version"]! as! String
                    let currentVersion = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleShortVersionString") as! String
                    if currentVersion.compare(latestVersion, options:NSStringCompareOptions.NumericSearch) == NSComparisonResult.OrderedAscending {
                        let forced = result["forced"]! as! Bool
                        let url = result["url"]! as! String
                        self.promptUserToUpdate(forced, url: url)
                    }
                }
        }
    }
    
    func promptUserToUpdate(forced: Bool, url: String) {
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
    
    func registerUser(callback: (Bool)->Void) {
        Alamofire.request(.POST, k.server_url+"join", parameters: ["phone_number":User.user.phoneNumber], encoding: .JSON)
            .responseJSON { request, response, json, error in
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
    
    func authenticateUser(callback: (Bool)->Void) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"confirm", parameters: ["phone_number":user.phoneNumber, "code":user.code], encoding: .JSON)
            .responseJSON { request, response, json, error in
                if let result = json as? [String:Bool] {
                    let success = result["success"]!
                    if success {
                        self.downloadInbox({}) //Preload inbox
                        Answers.logCustomEventWithName("Authenticate", customAttributes:nil)
                    }
                    callback(success)
                } else {
                    callback(false)
                }
        }
    }
    
    func sendPushToken() {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"pushtoken", parameters: ["phone_number":user.phoneNumber, "code":user.code, "push_token":user.pushToken], encoding: .JSON)
    }
    
    func downloadInbox(callback: ()->Void) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"inbox", parameters: ["phone_number": user.phoneNumber, "code":user.code, "last_updated":user.lastUpdated], encoding: .JSON)
            .responseJSON { request, response, json, error in
                if let result = json as? [String:AnyObject] {
                    if let inbox = result["inbox"] as? [[String:AnyObject]] {
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
                                
                                if var friend = realm.objects(Friend).filter("phoneNumber == %@", friendNumber).first {
                                    var shareDate = song["date"]! as! Int
                                    if shareDate > friend.lastShared {
                                        friend.lastShared = shareDate
                                    }
                                    if user.lastUpdated == 0 || incoming {
                                        friend.numShared++
                                    }
                                }
                            }
                            user.lastUpdated = result["updated"]! as! Int
                            callback()
                        }
                    }
                }
        }
    }
    
    //Might want to resend these if it fails the first time
    func listen(song: InboxSong) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"listen", parameters: ["phone_number":user.phoneNumber, "code":user.code, "id":song.id, "title":song.title, "artist":song.artist, "sender":song.sender, "listener_name":user.firstName], encoding: .JSON)
            .responseJSON { request, response, json, error in
                if let result = json as? [String:Bool] {
                    if !result["success"]! {
                        realm.write() {
                            song.listen = false
                        }
                    }
                } else {
                    realm.write() {
                        song.listen = false
                    }
                }
            }
        Answers.logCustomEventWithName("Listen", customAttributes: nil)
    }
    
    func love(song: InboxSong) {
        let user = User.user
        Alamofire.request(.POST, k.server_url+"love", parameters: ["phone_number":user.phoneNumber, "code":user.code, "id":song.id, "title":song.title, "artist":song.artist, "sender":song.sender, "lover_name":user.firstName], encoding: .JSON)
            .responseJSON { request, response, json, error in
                if let result = json as? [String:Bool] {
                    if !result["success"]! {
                        realm.write() {
                            song.love = false
                        }
                    }
                } else {
                    realm.write() {
                        song.love = false
                    }
                }
            }
        Answers.logCustomEventWithName("Love", customAttributes: nil)
    }
    
    func cachePushData(pushData: [String:AnyObject]) {
        if var sharedSong = pushData["share"] as? [String:AnyObject] {
            realm.write() {
                realm.create(InboxSong.self, value: sharedSong, update: true)
            }
        } else if let listenId = pushData["listen"] as? String {
            if let song = realm.objects(InboxSong).filter("id = %@", listenId).first {
                realm.write() {
                    song.listen = true
                }
            }
        } else if let loveId = pushData["love"] as? String {
            if let song = realm.objects(InboxSong).filter("id = %@", loveId).first {
                realm.write() {
                    song.love = true
                }
            }
        }
        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
        if let inboxViewController = navigationController.topViewController as? InboxViewController {
            inboxViewController.tableView.reloadData()
        }
    }
    
    func cacheAndSendSong(song: SendSong) {
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
        self.sendSongs()
        Answers.logCustomEventWithName("Share", customAttributes: nil)
    }
    
    func sendSongs() {
        
        let user = User.user
        let unsentSongs = realm.objects(SendSong)
        for song in unsentSongs {
            
            let params: [String:AnyObject] = ["phone_number": user.phoneNumber, "code": user.code, "title":song.title, "artist":song.artist, "yt_id":song.yt_id, "date":song.date, "updated":song.date, "recipients":song.recipients, "sender_name":user.firstName]
            Alamofire.request(.POST, k.server_url+"share", parameters: params, encoding: .JSON)
                .responseJSON { request, response, json, error in
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
                                        //Reload table view
                                        let navigationController = UIApplication.sharedApplication().keyWindow?.rootViewController as! UINavigationController
                                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
                                            inboxViewController.tableView.reloadData()
                                        }
                                        //Update playlist
                                        SongPlayer.songPlayer.updatePlaylist()
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
    
    func searchSong(query: String, callback: [SendSong]->Void) {
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
    
    func parseResults(items: [[String:[String:String]]]) -> [SendSong] {
        
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
    
    func getTitleAndArtist(songString: String) ->[String:String]? {
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
