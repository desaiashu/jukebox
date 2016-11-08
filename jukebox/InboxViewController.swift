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
    
    @IBOutlet weak var playerButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    var songs: Results<InboxSong>!
    
    var inSearch = false {
        didSet {
            self.cancelButton.isHidden = !inSearch
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
        SongPlayer.songPlayer.setup(self.playerButton, artistLabel: self.artistLabel, titleLabel: self.titleLabel, skipButton: self.skipButton)
        
        songs = realm.objects(InboxSong.self).sorted(byProperty: "date", ascending: false)
        //Could bump "new" songs to top - unsure how to deal with tapping play
        //var songs = realm.objects(InboxSong).sorted([SortDescriptor(property: "listen"), SortDescriptor(property: "date", ascending: false)])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.clearSearch()
    }
    
    func downloadData() {
        Server.server.downloadInbox({
            self.tableView.reloadData()
        })
    }
    
    func clearSearch() {
        self.searchTextField.text = ""
        self.searchTextField.resignFirstResponder()
        
        self.searchResults = []
        self.inSearch = false
    }
    
    @IBAction func cancelPressed(_ sender: UIButton) {
        self.clearSearch()
    }
    
    @IBAction func playerButtonPressed(_ sender: UIButton) {
        SongPlayer.songPlayer.playerButtonPressed()
    }
    
    @IBAction func skipButtonPressed(_ sender: UIButton) {
        SongPlayer.songPlayer.skip()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SendSongSegue" {
            self.searchTextField.resignFirstResponder()
            if let selectFriendsViewController = segue.destination as? SelectFriendsViewController {
                selectFriendsViewController.song = searchResults[(sender! as AnyObject).tag]
            }
        }
    }
}

extension InboxViewController: UITextFieldDelegate {
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
            
            Server.server.searchSong(newString, callback: { tempResults in
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
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if inSearch {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SelectSongCell", for: indexPath) as! SelectSongTableViewCell
            cell.song = searchResults[indexPath.row]
            cell.sendButton.tag = indexPath.row
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "InboxSongCell", for: indexPath) as! InboxSongTableViewCell
            cell.song = songs[indexPath.row]
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    func tableView(_ tableView: UITableView!, heightForRowAtIndexPath indexPath: IndexPath!) -> CGFloat {
        if inSearch {
            return SelectSongTableViewCell.rowHeight
        } else {
            return InboxSongTableViewCell.rowHeight
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if inSearch {
            return self.searchResults.count
        } else {
            return self.songs.count
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if inSearch {
            return false
        } else {
            return true
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAtIndexPath indexPath: IndexPath) -> [AnyObject]? {
        if inSearch {
            return nil
        } else if let cell = tableView.cellForRow(at: indexPath) as? InboxSongTableViewCell {
            
            let song = cell.song!
            var rowActions = [UITableViewRowAction]()
            
            let sendRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "Send", handler:
                { action, indexpath in
                    if let selectFriendsViewController = UIStoryboard(name: "Main", bundle: nil)
                        .instantiateViewController(withIdentifier: "SelectFriendsViewController") as? SelectFriendsViewController {
                            let songToSend = SendSong()
                            songToSend.title = song.title
                            songToSend.artist = song.artist
                            songToSend.yt_id = song.yt_id
                            selectFriendsViewController.song = songToSend
                            self.navigationController?.show(selectFriendsViewController, sender: self)
                    }
                    self.tableView.isEditing = false
            });
            
            sendRowAction.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.4)
            rowActions.append(sendRowAction)
            
            if !song.love && song.sender != User.user.phoneNumber {
                let loveRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: "Love", handler:
                    { action, indexPath in
                        song.heart()
                        self.tableView.isEditing = false
                        cell.directionLabel.text = "you love"
                });
                loveRowAction.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.55)
                rowActions.append(loveRowAction)
            }
            
            var muteTitle = "Mute"
            if cell.song!.mute {
                muteTitle = "Unmute"
            }
            let muteRowAction = UITableViewRowAction(style: UITableViewRowActionStyle.normal, title: muteTitle, handler:
                { action, indexpath in
                    if SongPlayer.songPlayer.playlist.count > 1 {
                        let mute = !song.mute
                        SongPlayer.songPlayer.toggleMute(cell.song!.yt_id, title: cell.song!.title, artist: cell.song!.artist, mute: mute)
                        try! realm.write() {
                            for sameSong in realm.objects(InboxSong.self).filter("yt_id = %@", cell.song!.yt_id)
                            {
                                sameSong.mute = mute
                            }
                        }
                    }
                    self.tableView.isEditing = false
            });
            muteRowAction.backgroundColor = UIColor(red: 185.0/255.0, green: 108.0/255.0, blue: 178.0/255.0, alpha: 0.2)
            rowActions.append(muteRowAction)
            
            return rowActions;
        }
        return nil
    }
    
}
