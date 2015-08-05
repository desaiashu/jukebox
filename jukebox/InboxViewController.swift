//
//  InboxViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit
import Alamofire
import RealmSwift
import XCDYouTubeKit

class InboxViewController: UIViewController {

    var videoPlayerController: XCDYouTubeVideoPlayerViewController?
    
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var videoView: UIView!
    
    var songs = g.realm.objects(InboxSong).sorted("date", ascending: false)
    
    var inSearch = false {
        didSet {
            cancelButton.hidden = !inSearch
            tableView.reloadData()
        }
    }
    
    var searchResults: [SendSong] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do I want to download data here??

    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.sendSongs()
        self.downloadData()
        
        self.clearSearch()
    }
    
    func clearSearch (){
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        
        searchResults = []
        inSearch = false
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        clearSearch()
        g.player.stop()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "sendSegue" {
            if let selectFriendsViewController = segue.destinationViewController as? SelectFriendsViewController {
                selectFriendsViewController.song = searchResults[sender!.tag]
            }
        }
        
    }

    func downloadData() {
        
        if let user = g.user {
            Alamofire.request(.POST, k.server_url+"inbox", parameters: ["phone_number": user.phone_number, "code":user.code, "last_updated":user.last_updated])
                .responseJSON { request, response, json, error in
                    println(json)
                    if let result = json as? [String:[[String:String]]] {
                        if let inbox = result["inbox"] {
                            self.saveData(inbox)
                            g.realm.write() {
                                user.last_updated = Int(NSDate().timeIntervalSince1970)
                            }
                        }
                    }
            }
        }

    }
    
    func sendSongs() {
        
        if let user = g.user {
            let unsentSongs = g.realm.objects(SendSong)
            
            for song in unsentSongs {
                
                let params: [String:AnyObject] = ["phone_number": user.phone_number, "code": user.code, "title":song.title, "artist":song.artist, "yt_id":song.yt_id, "date":song.date, "updated":song.date, "recipients":song.recipients]
                
                Alamofire.request(.POST, k.server_url+"inbox", parameters: params)
                    .responseJSON { request, response, json, error in
                        println(json)
                        if let result = json as? [String:Bool] {
                            if let success = result["result"] {
                                if success {
                                    g.realm.write() {
                                        g.realm.delete(song)
                                    }
                                }
                            }
                        }
                }
            }
            
            
        }
    }
    
    func saveData(inbox: [[String:String]]) {
        
        for song in inbox {
            if song["date"]! == song["updated"]! { //newly created
                let inboxSong = InboxSong()
                
                inboxSong.title = song["title"]!
                inboxSong.artist = song["artist"]!
                inboxSong.yt_id = song["yt_id"]!
                inboxSong.sender = song["sender"]!
                inboxSong.recipient = song["recipient"]!
                inboxSong.date = song["date"]!
                inboxSong.updated = song["updated"]!
                
                g.realm.write() { //slow to open write operation every time?
                    g.realm.add(inboxSong)
                }
            } else {
                //find and update
                
                //            if let loved = song["love"] {
                //                inboxSong.love = true
                //            }
            }
        }
        
        tableView.reloadData()
    }
    
    func search(query: String) {
        // Perform search, save results IF query matches current text
        //TODO: test on slow connection, don't overwrite search when wrong query
        if let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet()) {
            Alamofire.request(.GET, k.youtube_url+escapedQuery)
                .responseJSON { request, response, json, error in
                    if let result = json as? [String:[[String:[String:String]]]] {
                        if let items = result["items"] {
                            self.parseResults(items, query: query)
                        }
                    }
            }
        }
    }
    
    func parseResults(items: [[String:[String:String]]], query: String) {
        
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
        if searchTextField.text == query {
            searchResults = tempResults
        }
    }
    
    func getTitleAndArtist(songString: String) ->[String:String]? {
        if let indexOfDash = songString.rangeOfString(" - ")?.startIndex {
            var newString = songString.stringByReplacingOccurrencesOfString("Official Music Video", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Official Music Video", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Official Video", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Official Audio", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Video Official", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Lyric Video", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Audio Only", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Lyrics", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Official Cover Video", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("VEVO Presents", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Full Lyric Video", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("Explicit", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("On Screen", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("[]", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("[ ]", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("()", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            newString = newString.stringByReplacingOccurrencesOfString("( )", withString: "", options: NSStringCompareOptions.CaseInsensitiveSearch)
            
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

extension InboxViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        inSearch = true
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let newString = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        if newString != "" {
            search(newString)
        } else {
            searchResults = []
        }
        return true
    }
}

extension InboxViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        if inSearch {
            let cell = tableView.dequeueReusableCellWithIdentifier("SelectSongCell", forIndexPath: indexPath) as! SelectSongTableViewCell
            cell.song = searchResults[indexPath.row]
            cell.sendButton.tag = indexPath.row
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("InboxSongCell", forIndexPath: indexPath) as! InboxSongTableViewCell
            cell.song = songs[indexPath.row]
            return cell
        }
        
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(tableView: UITableView!, heightForRowAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        if inSearch {
            return 80.0
        } else {
            return 115.0
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if inSearch {
            return Int(searchResults.count)
        } else {
            return Int(songs.count)
        }
    }
    
}
