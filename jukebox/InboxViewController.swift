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
    
    var searchResults: [SearchSong] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.downloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        
        searchResults = []
        
        g.player.stop()
        
        inSearch = false
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if let segueIdentifier = identifier {
            if segueIdentifier == "searchSegue" && searchTextField.text == "" {
                return false
            }
        }
        return true
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let segueIdentifier = segue.identifier {
            if segueIdentifier == "searchSegue" {
                if let selectSongViewController = segue.destinationViewController as? SelectSongViewController {
                    selectSongViewController.initialQuery = searchTextField.text
                }
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
        var tempResults: [SearchSong] = []
        for item in items {
            let songString = item["snippet"]!["title"]!
            
            if let titleAndArtist = getTitleAndArtist(songString) {
                var song = SearchSong()
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
