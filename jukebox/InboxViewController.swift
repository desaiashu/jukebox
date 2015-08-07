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
    
    var songs = realm.objects(InboxSong).sorted([SortDescriptor(property: "listen"), SortDescriptor(property: "date", ascending: false)])
    
    var inSearch = false {
        didSet {
            self.cancelButton.hidden = !inSearch
            self.tableView.reloadData()
        }
    }
    
    var searchResults: [SendSong] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do I want to download data here??

    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        Server.sendSongs()
        Server.downloadInbox(tableView.reloadData)
        
        self.clearSearch()
    }
    
    func clearSearch (){
        self.searchTextField.text = ""
        self.searchTextField.resignFirstResponder()
        
        self.searchResults = []
        self.inSearch = false
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        self.clearSearch()
        SongPlayer.stop()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "sendSegue" {
            self.searchTextField.resignFirstResponder()
            if let selectFriendsViewController = segue.destinationViewController as? SelectFriendsViewController {
                selectFriendsViewController.song = searchResults[sender!.tag]
            }
            SongPlayer.stop()
        }
        
    }
}

extension InboxViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        self.inSearch = true
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let newString = (textField.text as NSString).stringByReplacingCharactersInRange(range, withString: string)
        if newString != "" {
            
            Server.searchSong(newString, callback: { tempResults in
                    if self.searchTextField.text == newString {
                        self.searchResults = tempResults
                    }
                })
            
        } else {
            self.searchResults = []
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
            return SelectSongTableViewCell.rowHeight
        } else {
            return InboxSongTableViewCell.rowHeight
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if inSearch {
            return Int(self.searchResults.count)
        } else {
            return Int(self.songs.count)
        }
    }
    
}
