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
        
        self.goButton.setTitleColor(UIColor.lightGray, for: UIControl.State.disabled)
        self.resendButton.setTitleColor(UIColor.lightGray, for: UIControl.State.disabled)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "AuthenticatedSegue" {
            return false
        }
        return true
    }
    
    @IBAction func goPressed(_ sender: UIButton) {
        self.confirmationCodeTextField.resignFirstResponder()
        self.statusLabel.text = "Loading..."
        self.statusLabel.isHidden = false
        self.goButton.isEnabled = false
        self.resendButton.isEnabled = false
        User.user.code = self.confirmationCodeTextField.text!
        Server.server.authenticateUser(self.authenticateCallback)
    }
    
    @IBAction func resendPressed(_ sender: UIButton) {
        self.resendButton.isEnabled = false
        self.resendButton.titleLabel?.text = "Sending"
        Server.server.registerUser({success in
            self.resendButton.titleLabel?.text = "Resend Code"
            self.resendButton.isEnabled = true
        })
    }
    
    func authenticateCallback(_ success: Bool) {
        if success {
            try! realm.write(){
                realm.add(User.user)
            }
            self.performSegue(withIdentifier: "AuthenticatedSegue", sender: self)
        } else {
            //This method should also take in an error code (ie if you're not connected to the server)
            self.statusLabel.text = "Incorrect code or error connecting to server"
            self.goButton.isEnabled = true
            self.resendButton.isEnabled = true
            User.user.code = ""
        }
    }
}

extension ConfirmationCodeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
