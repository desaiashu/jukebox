//
//  SelectFriendsViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit
import RealmSwift

class SelectFriendsViewController: UIViewController {
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    var song: SendSong?
    
    var bestFriends = realm.objects(Friend).filter("numShared > 0").sorted("numShared", ascending: false)
    var recentFriends: Results<Friend>?
    var allFriends = realm.objects(Friend).sorted("firstName")
    
    var selectedFriends: [String] = [] {
        didSet {
            if self.selectedFriends.count == 0 {
                sendButton.enabled = false
            } else {
                sendButton.enabled = true
            }
        }
    }
    
    var inSearch = false {
        didSet {
            self.cancelButton.hidden = !inSearch
            self.tableView.reloadData()
        }
    }
    
    var searchResults = realm.objects(Friend).filter("firstName BEGINSWITH '.!?'") {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.sendButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        
        let numBestFriends = min(self.bestFriends.count, 3)
        var bestFriendNumbers = [String]()
        if numBestFriends > 0 {
            for i in 0...numBestFriends-1 {
                bestFriendNumbers.append(self.bestFriends[i].phoneNumber)
            }
        }
        self.recentFriends = realm.objects(Friend).filter("lastShared > 0 AND NOT phoneNumber in %@", bestFriendNumbers).sorted("lastShared", ascending: false)
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
        self.searchTextField.text = ""
        self.searchTextField.resignFirstResponder()
        
        self.searchResults = realm.objects(Friend).filter("firstName BEGINSWITH '.!?'")
        
        self.inSearch = false
    }
    
    @IBAction func sendPressed(sender: UIButton) {
        self.song!.recipients = self.selectedFriends.joinWithSeparator(",")
        Server.server.cacheAndSendSong(self.song!)
        self.navigationController!.popViewControllerAnimated(true)
    }
}

extension SelectFriendsViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
        self.inSearch = true
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let newString = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString: string)
        if newString != "" {
            let query = newString.componentsSeparatedByString(" ")
            let first = query[0]
            var predicate = NSPredicate(format: "firstName BEGINSWITH[c] %@ OR lastName BEGINSWITH[c] %@", first, first)
            if query.count > 11{
                let last = query[1]
                predicate = NSPredicate(format: "firstName BEGINSWITH[c] %@ AND lastName BEGINSWITH[c] %@", first, last)
            }
            self.searchResults = realm.objects(Friend).filter(predicate).sorted("firstName")
        } else {
            self.searchResults = realm.objects(Friend).filter("firstName BEGINSWITH '.!?'")
        }
        
        return true
    }
    
    func flip(sender: UISwitch) {
        let cell = sender.superview!.superview as! SelectFriendsTableViewCell
        if sender.on {
            self.selectedFriends.append(cell.friend!.phoneNumber)
        } else {
            self.selectedFriends.removeAtIndex(self.selectedFriends.indexOf(cell.friend!.phoneNumber)!)
        }
    }
}

extension SelectFriendsViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        //TODO create sections for recent / selected?
        //Add "numSent/recieved" to each friend when sending + downloading data, when data downloaded add "lastSent/recieved" timestamp, query for top 5 most sent + 5 most recently sent (save to server?)
        let cell = tableView.dequeueReusableCellWithIdentifier("SelectFriendsCell", forIndexPath: indexPath) as! SelectFriendsTableViewCell
        if cell.friend == nil {
            cell.selectSwitch.addTarget(self, action: #selector(flip(_:)), forControlEvents: UIControlEvents.ValueChanged)
        }
        if inSearch {
            cell.friend = self.searchResults[indexPath.row]
        } else {
            switch (indexPath.section) {
            case 0:
                cell.friend = self.bestFriends[indexPath.row]
            case 1:
                cell.friend = self.recentFriends![indexPath.row]
            default:
                cell.friend = self.allFriends[indexPath.row]
            }
        }
        cell.selectSwitch.on = self.selectedFriends.contains(cell.friend!.phoneNumber)
        
        return cell
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if inSearch {
            return 1
        } else {
            return 3
        }
    }
    
    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if inSearch {
            return 0.0
        } else {
            return SelectFriendsTableViewHeader.height
        }
    }
    
    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if inSearch {
            return nil
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("SelectFriendsHeader") as! SelectFriendsTableViewHeader
            switch (section) {
            case 0:
                cell.headerLabel.text = "Best Friends"
            case 1:
                cell.headerLabel.text = "Recents"
            default:
                cell.headerLabel.text = "All"
            }
            return cell.contentView
        }
    }
    
    func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if inSearch {
            return self.searchResults.count
        } else {
            switch (section) {
            case 0:
                return min(self.bestFriends.count, 3)
            case 1:
                return min(self.recentFriends!.count, 3)
            default:
                return self.allFriends.count
            }
        }
    }
    
}
