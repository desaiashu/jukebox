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
        
        self.accessContactsButton.setTitleColor(UIColor.lightGray, for: UIControl.State.disabled)
        self.enablePushButton.setTitleColor(UIColor.lightGray, for: UIControl.State.disabled)
    }
    
    @IBAction func accessContacts(_ sender: UIButton) {
        Permissions.permissions.authorizeAddressBook { success in
            if success {
                self.accessContactsButton.isEnabled = false
                if self.enablePushButton.isEnabled == false {
                    self.next()
                }
            }
        }
    }
    
    @IBAction func enablePush(_ sender: UIButton) {
        Permissions.permissions.enablePush({
            self.enablePushButton.isEnabled = false
            if self.accessContactsButton.isEnabled == false {
                self.next()
            }
        })
    }
    
    func next() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.presentCore()
    }
}
