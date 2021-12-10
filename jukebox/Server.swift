//
//  Server.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/5/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import Alamofire
import UIKit

struct k {
    static let server_url = "https://jkbx.es/"
    static let youtube_url = "https://www.googleapis.com/youtube/v3/search?key=AIzaSyBK4c6lUvrKyH3rt3dbsSS-jUVPDjRGyT0&part=snippet&type=video&videoCategoryId=10&order=relevance&maxResults=50&fields=items(id(videoId)%2Csnippet(title))&q="
}

class Server {
    static let server = Server()
    
    func checkVersion() {
        Alamofire.request(k.server_url+"version")
            .responseJSON { response in
                if let result = response.result.value as? [String:AnyObject] {
                    let latestVersion = result["version"]! as! String
                    let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
                    if currentVersion.compare(latestVersion, options:NSString.CompareOptions.numeric) == ComparisonResult.orderedAscending {
                        let forced = result["forced"]! as! Bool
                        let url = result["url"]! as! String
                        self.promptUserToUpdate(forced, url: url)
                    }
                }
        }
    }
    
    func promptUserToUpdate(_ forced: Bool, url: String) {
        var title: String?
        var message: String?
        if forced {
            title = "Update Required"
            message = "You must update the app to continue using, tap update to download"
        } else {
            title = "Update Available"
            message = "A new update is available, tap update to download"
        }
        let alertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        if !forced {
            alertController.addAction(UIAlertAction(title: "Later", style: UIAlertActionStyle.cancel, handler:nil))
        }
        alertController.addAction(
            UIAlertAction(title: "Update", style: UIAlertActionStyle.default, handler: { UIAlertAction in
                UIApplication.shared.openURL(URL(string: url)!)
            })
        )
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
    
    func registerUser(_ callback: @escaping (Bool)->Void) {
        let r = Alamofire.request(k.server_url+"join", method: .post, parameters: ["phone_number":User.user.phoneNumber], encoding: JSONEncoding.default)
            .responseJSON { response in
                if let result = response.result.value as? [String:Bool] {
                    let success = result["success"]!
                    if success {
                        Answers.logCustomEvent(withName: "Register", customAttributes:nil)
                    }
                    callback(success)
                } else {
                    callback(false)
                }
        }
        let j = 0;
    }
    
    func authenticateUser(_ callback: @escaping (Bool)->Void) {
        let user = User.user
        Alamofire.request(k.server_url+"confirm", method: .post, parameters: ["phone_number":user.phoneNumber, "code":user.code], encoding: JSONEncoding.default)
            .responseJSON { response in
                if let result = response.result.value as? [String:Bool] {
                    let success = result["success"]!
                    if success {
                        self.downloadInbox({}) //Preload inbox
                        Answers.logCustomEvent(withName: "Authenticate", customAttributes:nil)
                    }
                    callback(success)
                } else {
                    callback(false)
                }
        }
    }
    
    func sendPushToken() {
        let user = User.user
        Alamofire.request(k.server_url+"pushtoken", method: .post, parameters: ["phone_number":user.phoneNumber, "code":user.code, "push_token":user.pushToken], encoding: JSONEncoding.default)
    }
    
    func downloadInbox(_ callback: @escaping ()->Void) {
        let user = User.user
        Alamofire.request(k.server_url+"inbox", method: .post, parameters: ["phone_number": user.phoneNumber, "code":user.code, "last_updated":user.lastUpdated], encoding: JSONEncoding.default)
            .responseJSON { response in
                if let result = response.result.value as? [String:AnyObject] {
                    if let inbox = result["inbox"] as? [[String:AnyObject]] {
                        try! realm.write() {
                            for song in inbox {
                                realm.create(InboxSong.self, value: song, update: true)
                                    
                                if user.addressBookLoaded { //Update best and recent friends
                                    var incoming = true
                                    var friendNumber = song["sender"]! as! String
                                    if friendNumber == user.phoneNumber {
                                        friendNumber = song["recipient"]! as! String
                                        incoming = false
                                    }
                                    
                                    let shareDate = song["date"]! as! Int
                                    if let friend = realm.objects(Friend.self).filter("phoneNumber == %@", friendNumber).first {
                                        if shareDate > friend.lastShared {
                                            friend.lastShared = shareDate
                                        }
                                        if user.lastUpdated == 0 || incoming {
                                            friend.numShared += 1
                                        }
                                    } else {
                                        let newFriend = Friend()
                                        newFriend.phoneNumber = friendNumber
                                        newFriend.firstName = friendNumber
                                        newFriend.lastName = ""
                                        newFriend.lastShared = shareDate
                                        newFriend.numShared = 1
                                        realm.add(newFriend)
                                    }
                                }
                            }
                            user.lastUpdated = result["updated"]! as! Int
                        }
                        callback()
                        if inbox.count > 0 {
                            SongPlayer.songPlayer.updatePlaylist() //Maybe only do this if there's a new song not just an updated song
                        }
                    }
                }
        }
    }
    
    //Might want to resend these if it fails the first time
    func listen(_ song: InboxSong) {
        let user = User.user
        Alamofire.request(k.server_url+"listen", method: .post, parameters: ["phone_number":user.phoneNumber, "code":user.code, "id":song.id, "title":song.title, "artist":song.artist, "sender":song.sender, "listener_name":user.firstName], encoding: JSONEncoding.default)
            .responseJSON { response in
                if let result = response.result.value as? [String:Bool] {
                    if !result["success"]! {
                        try! realm.write() {
                            song.listen = false
                        }
                    }
                } else {
                    try! realm.write() {
                        song.listen = false
                    }
                }
            }
        Answers.logCustomEvent(withName: "Listen", customAttributes: nil)
    }
    
    func love(_ song: InboxSong) {
        let user = User.user
        Alamofire.request(k.server_url+"love", method: .post, parameters: ["phone_number":user.phoneNumber, "code":user.code, "id":song.id, "title":song.title, "artist":song.artist, "sender":song.sender, "lover_name":user.firstName], encoding: JSONEncoding.default)
            .responseJSON { response in
                if let result = response.result.value as? [String:Bool] {
                    if !result["success"]! {
                        try! realm.write() {
                            song.love = false
                        }
                    }
                } else {
                    try! realm.write() {
                        song.love = false
                    }
                }
            }
        Answers.logCustomEvent(withName: "Love", customAttributes: nil)
    }
    
    func cachePushData(_ pushData: [String:AnyObject]) {
        if let sharedSong = pushData["share"] as? [String:AnyObject] {
            try! realm.write() {
                realm.create(InboxSong.self, value: sharedSong, update: true)
            }
        } else if let listenId = pushData["listen"] as? String {
            if let song = realm.objects(InboxSong.self).filter("id = %@", listenId).first {
                try! realm.write() {
                    song.listen = true
                }
            }
        } else if let loveId = pushData["love"] as? String {
            if let song = realm.objects(InboxSong.self).filter("id = %@", loveId).first {
                try! realm.write() {
                    song.love = true
                }
            }
        }
        let navigationController = UIApplication.shared.keyWindow?.rootViewController as! UINavigationController
        if let inboxViewController = navigationController.topViewController as? InboxViewController {
            inboxViewController.tableView.reloadData()
        }
    }
    
    func cacheAndSendSong(_ song: SendSong) {
        let now = Int(Date().timeIntervalSince1970)
        song.date = now
        try! realm.write() {
            realm.add(song)
            
            let recipients = song.recipients.characters.split {$0 == ","}.map { String($0) }
            for recipient in recipients {
                let inboxSong = InboxSong()
                
                inboxSong.title = song.title
                inboxSong.artist = song.artist
                inboxSong.yt_id = song.yt_id
                inboxSong.sender = User.user.phoneNumber
                inboxSong.recipient = recipient
                inboxSong.date = song.date
                inboxSong.updated = song.date
                inboxSong.id = String(song.date)+recipient
                
                realm.add(inboxSong)
                
                let friend = realm.objects(Friend.self).filter("phoneNumber == %@", recipient).first
                friend?.lastShared = song.date
                friend?.numShared += 1
            }
        }
        self.sendSongs()
        SongPlayer.songPlayer.updatePlaylist()
        Answers.logCustomEvent(withName: "Share", customAttributes: nil)
    }
    
    func sendSongs() {
        
        let user = User.user
        let unsentSongs = realm.objects(SendSong.self)
        for song in unsentSongs {
            
            let params: [String:Any] = ["phone_number": user.phoneNumber, "code": user.code, "title":song.title, "artist":song.artist, "yt_id":song.yt_id, "date":song.date, "updated":song.date, "recipients":song.recipients, "sender_name":user.firstName]
            Alamofire.request(k.server_url+"share", method: .post, parameters: params, encoding: JSONEncoding.default)
                .responseJSON { response in
                    if let result = response.result.value as? [String:[[String:AnyObject]]] {
                        if let songs = result["songs"] {
                            try! realm.write() {
                                for downloadedSong in songs {
                                    //Save new copy w/ id from server
                                    realm.create(InboxSong.self, value: downloadedSong, update: true)
                                    
                                    //Delete old copy w/ old id
                                    let old_id = String(song.date)+(downloadedSong["recipient"]! as! String)
                                    if let inboxSong = realm.objects(InboxSong.self).filter("id == %@", old_id).first {
                                        realm.delete(inboxSong)
                                        //Reload table view
                                        let navigationController = UIApplication.shared.keyWindow?.rootViewController as! UINavigationController
                                        if let inboxViewController = navigationController.topViewController as? InboxViewController {
                                            inboxViewController.tableView.reloadData()
                                        }
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
    
    func searchSong(_ query: String, callback: @escaping ([SendSong])->Void) {
        if let escapedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
            Alamofire.request(k.youtube_url+escapedQuery)
                .responseJSON { response in
                    if let result = response.result.value as? [String:[[String:[String:String]]]] {
                        if let items = result["items"] {
                            
                            let tempResults = self.parseResults(items)
                            callback(tempResults)
                        }
                    }
            }
        }
    }
    
    func parseResults(_ items: [[String:[String:String]]]) -> [SendSong] {
        
        //TODO: Make this smarter, eliminate duplicates + crap results, cross relevance + view count?
        var tempResults: [SendSong] = []
        for item in items {
            let songString = item["snippet"]!["title"]!
            
            if let titleAndArtist = getTitleAndArtist(songString) {
                let song = SendSong()
                song.title = titleAndArtist["title"]!
                song.artist = titleAndArtist["artist"]!
                song.yt_id = item["id"]!["videoId"]!
                tempResults.append(song)
            }
        }
        return tempResults
    }
    
    func getTitleAndArtist(_ songString: String) ->[String:String]? {
        if (songString.range(of: " - ")?.lowerBound) != nil {
            var newString = songString
            
            newString = self.stripParens(newString)
            newString = self.stripParens(newString)
            newString = self.stripBrackets(newString)
            newString = self.stripBrackets(newString)
            // Hack to catch multiple sets of parens or brackets
            
            let stringsToRemove = ["Official Music Video","Official Music Video","Official Video","Official Audio","Video Official","Lyric Video","Audio Only","Lyrics","Official Cover Video","VEVO Presents","Full Lyric Video","Explicit","On Screen"]
            for string in stringsToRemove {
                newString = newString.replacingOccurrences(of: string, with: "", options: NSString.CompareOptions.caseInsensitive)
            }
            
            if let rangeOfDash = newString.range(of: " - ") {
                let artist = newString.substring(to: rangeOfDash.lowerBound).trimmingCharacters(in: CharacterSet(charactersIn: " \""))
                var title = newString.substring(from: rangeOfDash.upperBound).trimmingCharacters(in: CharacterSet(charactersIn: " \""))
                
                if let startIndexOfSecondDash = title.range(of: " - ")?.lowerBound {
                    title = title.substring(to: startIndexOfSecondDash).trimmingCharacters(in: CharacterSet(charactersIn: " \""))
                }
                
                return ["artist":artist, "title":title];
            }
        }
        
        return nil
    }
    
    func stripParens(_ string: String) -> String {
        if let rangeOfBracket = string.range(of: "(") {
            
            let startIndexOfBracket = rangeOfBracket.lowerBound
            if let endIndexOfBracket = string.range(of: ")")?.upperBound {
                let pre = string.substring(to: startIndexOfBracket).trimmingCharacters(in: CharacterSet(charactersIn: " "))
                let contents = string.substring(with: startIndexOfBracket..<endIndexOfBracket)
                let post = string.substring(from: endIndexOfBracket)
                
                if contents.range(of: "Remix") != nil || string.range(of: "remix") != nil || string.range(of: "REMIX") != nil || contents.range(of: "Cover") != nil || string.range(of: "cover") != nil || string.range(of: "COVER") != nil {
                    return string //If centerpart contains remix or cover, don't remove parens
                } else {
                    return pre + post
                }
                
            } //What if parens aren't closed?
        }
        
        return string
    }
    
    func stripBrackets(_ string: String) -> String {
        if let rangeOfBracket = string.range(of: "[") {
            
            let startIndexOfBracket = rangeOfBracket.lowerBound
            if let endIndexOfBracket = string.range(of: "]")?.upperBound {
                let pre = string.substring(to: startIndexOfBracket).trimmingCharacters(in: CharacterSet(charactersIn: " "))
                let contents = string.substring(with: startIndexOfBracket..<endIndexOfBracket)
                let post = string.substring(from: endIndexOfBracket)
                
                if contents.range(of: "Remix") != nil || string.range(of: "remix") != nil || string.range(of: "REMIX") != nil || contents.range(of: "Cover") != nil || string.range(of: "cover") != nil || string.range(of: "COVER") != nil {
                    return string //If centerpart contains remix or cover, don't remove brackets
                } else {
                    return pre + post
                }
                
            } //What if brackets aren't closed?
        }
        
        return string
    }
}
