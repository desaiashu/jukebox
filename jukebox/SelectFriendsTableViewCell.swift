//
//  SelectFriendsTableViewCell.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class SelectFriendsTableViewCell: UITableViewCell {
    
    static var rowHeight: CGFloat = 80.0
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var selectSwitch: UISwitch!
    
    var friend: Friend? {
        didSet {
            if let friend = friend {
                self.nameLabel.text = friend.firstName+" "+friend.lastName
            }
        }
    }
    
}
