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
    
    var bestFriends = realm.objects(Friend.self).filter("numShared > 0").sorted(byKeyPath: "numShared", ascending: false)
    var recentFriends: Results<Friend>?
    var allFriends = realm.objects(Friend.self).sorted(byKeyPath: "firstName")
    
    var selectedFriends: [String] = [] {
        didSet {
            if self.selectedFriends.count == 0 {
                sendButton.isEnabled = false
            } else {
                sendButton.isEnabled = true
            }
        }
    }
    
    var inSearch = false {
        didSet {
            self.cancelButton.isHidden = !inSearch
            self.tableView.reloadData()
        }
    }
    
    var searchResults = realm.objects(Friend.self).filter("firstName BEGINSWITH '.!?'") {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.sendButton.setTitleColor(UIColor.lightGray, for: UIControlState.disabled)
        
        let numBestFriends = min(self.bestFriends.count, 3)
        var bestFriendNumbers = [String]()
        if numBestFriends > 0 {
            for i in 0...numBestFriends-1 {
                bestFriendNumbers.append(self.bestFriends[i].phoneNumber)
            }
        }
        self.recentFriends = realm.objects(Friend.self).filter("lastShared > 0 AND NOT phoneNumber in %@", bestFriendNumbers).sorted(byKeyPath: "lastShared", ascending: false)
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.searchTextField.text = ""
        self.searchTextField.resignFirstResponder()
        
        self.searchResults = realm.objects(Friend.self).filter("firstName BEGINSWITH '.!?'")
        
        self.inSearch = false
    }
    
    @IBAction func sendPressed(_ sender: UIButton) {
        self.song!.recipients = self.selectedFriends.joined(separator: ",")
        Server.server.cacheAndSendSong(self.song!)
        self.navigationController!.popViewController(animated: true)
    }
}

extension SelectFriendsViewController: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        self.inSearch = true
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newString = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        if newString != "" {
            let query = newString.components(separatedBy: " ")
            let first = query[0]
            var predicate = NSPredicate(format: "firstName BEGINSWITH[c] %@ OR lastName BEGINSWITH[c] %@", first, first)
            if query.count > 1 {
                let last = query[1]
                predicate = NSPredicate(format: "firstName BEGINSWITH[c] %@ AND lastName BEGINSWITH[c] %@", first, last)
            }
            self.searchResults = realm.objects(Friend.self).filter(predicate).sorted(byKeyPath: "firstName")
        } else {
            self.searchResults = realm.objects(Friend.self).filter("firstName BEGINSWITH '.!?'")
        }
        
        return true
    }
    
    @objc func flip(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        let cell = sender.superview!.superview as! SelectFriendsTableViewCell
        if sender.isSelected {
            self.selectedFriends.append(cell.friend!.phoneNumber)
        } else {
            self.selectedFriends.remove(at: self.selectedFriends.index(of: cell.friend!.phoneNumber)!)
        }
    }
}

extension SelectFriendsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //TODO create sections for recent / selected?
        //Add "numSent/recieved" to each friend when sending + downloading data, when data downloaded add "lastSent/recieved" timestamp, query for top 5 most sent + 5 most recently sent (save to server?)
        let cell = tableView.dequeueReusableCell(withIdentifier: "SelectFriendsCell", for: indexPath) as! SelectFriendsTableViewCell
        if cell.friend == nil {
            cell.selectSwitch.addTarget(self, action: #selector(flip(_:)), for: UIControlEvents.touchUpInside)
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
        cell.selectSwitch.isSelected = self.selectedFriends.contains(cell.friend!.phoneNumber)
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if inSearch {
            return 1
        } else {
            return 3
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if inSearch {
            return 0.0
        } else {
            return SelectFriendsTableViewHeader.height
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if inSearch {
            return nil
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectFriendsHeader") as! SelectFriendsTableViewHeader
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
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
