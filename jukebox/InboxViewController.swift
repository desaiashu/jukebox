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
    
    var songs = realm.objects(InboxSong).sorted("date", ascending: false)
    //Could bump "new" songs to top - unsure how to deal with tapping play
    //var songs = realm.objects(InboxSong).sorted([SortDescriptor(property: "listen"), SortDescriptor(property: "date", ascending: false)])
    
    
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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.clearSearch()
    }
    
    func downloadData() {
        Server.downloadInbox({
            self.tableView.reloadData()
        })
    }
    
    func clearSearch() {
        self.searchTextField.text = ""
        self.searchTextField.resignFirstResponder()
        
        self.searchResults = []
        self.inSearch = false
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        self.clearSearch()
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "SendSongSegue" {
            self.searchTextField.resignFirstResponder()
            if let selectFriendsViewController = segue.destinationViewController as? SelectFriendsViewController {
                selectFriendsViewController.song = searchResults[sender!.tag]
            }
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
            return self.searchResults.count
        } else {
            return self.songs.count
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if inSearch {
            return false
        } else {
            return true
        }
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [AnyObject]? {
        if inSearch {
            return nil
        } else if let cell = tableView.cellForRowAtIndexPath(indexPath) as? InboxSongTableViewCell {
            
            var song = cell.song!
            var rowActions = [UITableViewRowAction]()
            
            
            
            var sendRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "Send", handler:
                { action, indexpath in
                    if let selectFriendsViewController = UIStoryboard(name: "Main", bundle: nil)
                        .instantiateViewControllerWithIdentifier("SelectFriendsViewController") as? SelectFriendsViewController {
                            var songToSend = SendSong()
                            songToSend.title = song.title
                            songToSend.artist = song.artist
                            songToSend.yt_id = song.yt_id
                            selectFriendsViewController.song = songToSend
                            self.navigationController?.showViewController(selectFriendsViewController, sender: self)
                    }
                    //maybe add better animation using setediting
                    self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
            });
            
            sendRowAction.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.4)
            rowActions.append(sendRowAction)
            
            if !song.love && song.sender != User.user.phoneNumber {
                var loveRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: "Love", handler:
                    { action, indexPath in
                        song.heart()
                        //maybe add better animation using setediting
                        self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
                });
                loveRowAction.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.55)
                rowActions.append(loveRowAction)
            }
            
            var muteTitle = "Mute"
            if cell.song!.mute {
                muteTitle = "Unmute"
            }
            var muteRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.Normal, title: muteTitle, handler:
                { action, indexpath in
                    let mute = !song.mute
                    realm.write() {
                        for sameSong in realm.objects(InboxSong).filter("yt_id = %@", cell.song!.yt_id)
                        {
                            sameSong.mute = mute
                        }
                    }
                    //maybe add better animation using setediting
                    self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
            });
            muteRowAction.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.2)
            rowActions.append(muteRowAction)
            
            return rowActions;
        }
        return nil
    }
    
}
