//
//  SelectFriendsViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class SelectFriendsViewController: UIViewController {
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    var song: SendSong?
    
    var friends = g.realm.objects(Friend).sorted("firstName", ascending: true)
    
    var selectedFriends: [String] = []
    
    var inSearch = false {
        didSet {
            cancelButton.hidden = !inSearch
            tableView.reloadData()
        }
    }
    
    var searchResults = g.realm.objects(Friend).filter("firstName BEGINSWITH '.!?'") {
        didSet {
            tableView.reloadData()
        }
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        
        searchResults = g.realm.objects(Friend).filter("firstName BEGINSWITH '.!?'")
        
        inSearch = false
    }
    
    @IBAction func sendPressed(sender: UIButton) {
        
        if let song = song {
            
            song.recipients = ",".join(selectedFriends)
            let now = Int(NSDate().timeIntervalSince1970)
            song.date = now
            g.realm.write() {
                g.realm.add(self.song!)
            }
            
            var recipients = split(song.recipients) {$0 == ","}
            for recipient in recipients {
                var inboxSong = InboxSong()
                
                inboxSong.title = song.title
                inboxSong.artist = song.artist
                inboxSong.yt_id = song.yt_id
                inboxSong.sender = g.user!.phone_number
                inboxSong.recipient = recipient
                inboxSong.date = song.date
                inboxSong.updated = song.date
                
                g.realm.write() {
                    g.realm.add(inboxSong)
                }
            }
        }
        
        self.navigationController!.popViewControllerAnimated(true)
    }
}

extension SelectFriendsViewController: UITextFieldDelegate {
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
            searchResults = g.realm.objects(Friend).filter("firstName BEGINSWITH[c] '"+newString+"' OR lastName BEGINSWITH[c] '"+newString+"'").sorted("firstName", ascending: true)
        } else {
            searchResults = g.realm.objects(Friend).filter("firstName BEGINSWITH '.!?'")
        }
        
        return true
    }
    
    func flip(sender: UISwitch) {
        var phoneNumber: String?
        let cell = sender.superview!.superview as! SelectFriendsTableViewCell
        if sender.on {
            selectedFriends.append(cell.friend!.phoneNumber)
        } else {
            selectedFriends.removeAtIndex(find(selectedFriends, cell.friend!.phoneNumber)!)
        }
    }
}

extension SelectFriendsViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        //TODO create sections for recent / selected?
        //Add "numSent/recieved" to each friend when sending + downloading data, when data downloaded add "lastSent/recieved" timestamp, query for top 5 most sent + 5 most recently sent (save to server?)
        let cell = tableView.dequeueReusableCellWithIdentifier("SelectFriendCell", forIndexPath: indexPath) as! SelectFriendsTableViewCell
        if cell.friend == nil {
            cell.selectSwitch.addTarget(self, action: "flip:", forControlEvents: UIControlEvents.ValueChanged)
        }
        if inSearch {
            cell.friend = searchResults[indexPath.row]
        } else {
            cell.friend = friends[indexPath.row]
        }
        cell.selectSwitch.on = contains(selectedFriends, cell.friend!.phoneNumber)
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if inSearch {
            return Int(searchResults.count)
        } else {
            return Int(friends.count)
        }
    }
    
}
