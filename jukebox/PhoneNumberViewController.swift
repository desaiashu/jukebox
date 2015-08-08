//
//  PhoneNumberViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class PhoneNumberViewController: UIViewController {
    
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.goButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        User.user.phoneNumber = ""
        User.user.code = ""
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if identifier == "RegisteredSegue" {
            return false
        }
        return true
    }
    
    @IBAction func go(){
        self.phoneNumberTextField.resignFirstResponder()
        var phoneNumber = phoneNumberTextField.text
        if phoneNumber != "" {
            phoneNumber = String(phoneNumber.toInt()!) //Remove leading 0's
            if count(phoneNumber) == 10 { //Automatically including 1 for US numbers
                phoneNumber = "1".stringByAppendingString(phoneNumber)
            }
            User.user.phoneNumber = "+".stringByAppendingString(phoneNumber)
            self.goButton.enabled = false
            self.statusLabel.text = "Loading..."
            Server.registerUser(self.registerCallback)
        }
    }
    
    func registerCallback(success: Bool) {
        if success {
            self.performSegueWithIdentifier("RegisteredSegue", sender: self)
        } else {
            //This method should also take in an error code (ie if you're not connected to the server)
            self.statusLabel.text = "Error connecting to server, try again"
            self.goButton.enabled = true
            User.user.phoneNumber = ""
            User.user.code = ""
        }
    }
    
    @IBAction func prepareForUnwind(segue:UIStoryboardSegue) {
        self.statusLabel.text = "Include country code"
        self.goButton.enabled = true
        User.user.phoneNumber = ""
    }
}
