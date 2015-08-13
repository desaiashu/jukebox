//
//  EnableServicesViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class PermissionsViewController: UIViewController {
    
    @IBOutlet weak var accessContactsButton: UIButton!
    @IBOutlet weak var enablePushButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.accessContactsButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        self.enablePushButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
    }
    
    @IBAction func accessContacts(sender: UIButton) {
        Permissions.permissions.authorizeAddressBook { success in
            if success {
                self.accessContactsButton.enabled = false
                if self.enablePushButton.enabled == false {
                    self.next()
                }
            }
        }
    }
    
    @IBAction func enablePush(sender: UIButton) {
        Permissions.permissions.enablePush({
            self.enablePushButton.enabled = false
            if self.accessContactsButton.enabled == false {
                self.next()
            }
        })
    }
    
    func next() {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.presentCore()
    }
}
