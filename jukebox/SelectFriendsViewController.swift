//
//  SelectFriendsViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class SelectFriendsViewController: UIViewController {
    
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    
    var song: SearchSong?
    
    var friends = g.realm.objects(Friend).sorted("firstName", ascending: true)
    
    var inSearch = false {
        didSet {
            //cancelButton.hidden = !inSearch
            tableView.reloadData()
        }
    }
    
    var searchResults = g.realm.objects(Friend).sorted("firstName", ascending: true) {
        didSet {
            tableView.reloadData()
        }
    }
    
    @IBAction func cancelPressed(sender: UIButton) {
//        searchTextField.text = ""
//        searchTextField.resignFirstResponder()
//        
//        searchResults = g.realm.objects(Friend).sorted("firstName", ascending: true)
        
        inSearch = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        searchResults = g.realm.objects(Friend).filter("firstName BEGINSWITH "+newString+" OR lastName BEGINSWITH "+newString).sorted("firstName", ascending: true)
        return true
    }
}

extension SelectFriendsViewController: UITableViewDataSource {
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        //TODO create sections for recent / selected?
        let cell = tableView.dequeueReusableCellWithIdentifier("SelectFriendCell", forIndexPath: indexPath) as! SelectFriendsTableViewCell
        if inSearch {
            cell.friend = searchResults[indexPath.row]
        } else {
            cell.friend = friends[indexPath.row]
        }
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
