//
//  ConfirmationCodeViewController.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit

class ConfirmationCodeViewController: UIViewController {
    
    @IBOutlet weak var confirmationCodeTextField: UITextField!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var resendButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.goButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
        self.resendButton.setTitleColor(UIColor.lightGrayColor(), forState: UIControlState.Disabled)
    }
    
    override func shouldPerformSegueWithIdentifier(identifier: String?, sender: AnyObject?) -> Bool {
        if identifier == "AuthenticatedSegue" {
            return false
        }
        return true
    }
    
    @IBAction func goPressed(sender: UIButton) {
        self.confirmationCodeTextField.resignFirstResponder()
        self.statusLabel.text = "Loading..."
        self.statusLabel.hidden = false
        User.user.code = self.confirmationCodeTextField.text
        Server.authenticateUser(self.authenticateCallback)
    }
    
    func authenticateCallback(success: Bool) {
        if success {
            realm.write(){
                realm.add(User.user)
            }
            self.performSegueWithIdentifier("AuthenticatedSegue", sender: self)
        } else {
            //This method should also take in an error code (ie if you're not connected to the server)
            self.statusLabel.text = "Incorrect code or error connecting to server, try again or go back"
            self.goButton.enabled = true
            self.resendButton.enabled = true
            User.user.code = ""
        }
    }
}

extension ConfirmationCodeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
