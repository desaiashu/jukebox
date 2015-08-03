//
//  SelectSongViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit
import Alamofire

class SelectSongViewController: UIViewController {

    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    var initialQuery = ""
    
    @IBOutlet weak var searchTextField: UITextField!
    
    var searchResults: [SearchSong] = [] {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        searchTextField.text = initialQuery
        
        search(searchTextField.text)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func search(query: String) {
    // Perform search, save results IF query matches current text
        //TODO: test on slow connection, don't overwrite search when wrong query
        if let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet()) {
            Alamofire.request(.GET, k.youtube_url+escapedQuery)
                .responseJSON { request, response, json, error in
                    if let result = json as? [String:[[String:[String:String]]]] {
                        if let items = result["items"] {
                            self.parseResults(items)
                        }
                    }
            }
        }
    }
    
    func parseResults(items: [[String:[String:String]]]) {
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
        searchResults = tempResults
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

extension SelectSongViewController: UITextFieldDelegate {
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let newString = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        if newString != "" {
            search(newString)
        }
        return true
    }
}

extension SelectSongViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SelectSongCell", forIndexPath: indexPath) as! SelectSongTableViewCell
        cell.song = searchResults[indexPath.row]
        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Int(searchResults.count)
    }
    
}