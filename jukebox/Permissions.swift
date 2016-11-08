//
//  AddressBook.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/2/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import Foundation
import AddressBook
import RealmSwift
import UIKit

class Permissions {
    static let permissions = Permissions()
    
    var addressBookCallback: ((Bool)->Void)?
    var pushCallback: (()->Void)?
    var localDialingCode = ""
    
    init() {
        self.setLocalDialingCode()
    }
    
    func promptUserToChangeAddressBookSettings(_ forced: Bool) {
        let alertController = UIAlertController(title: "Contacts", message: "We need access to your contacts so you can send songs to your friends. Tap go to enable access to contacts in settings.", preferredStyle: UIAlertControllerStyle.alert)
        if !forced {
            alertController.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        }
        alertController.addAction(
            UIAlertAction(title: "Go", style: UIAlertActionStyle.default, handler: { UIAlertAction in
                UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
            })
        )
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
    
    func authorizeAddressBook (_ callback: @escaping (Bool)->Void){
        switch ABAddressBookGetAuthorizationStatus(){
        case .authorized, .notDetermined:
            self.addressBookCallback = callback
            self.loadAddressBook()
        case .denied, .restricted:
            self.promptUserToChangeAddressBookSettings(true)
            callback(false)
        }
    }
    
    func loadAddressBook() {
        var error: Unmanaged<CFError>?
        let addressBook: ABAddressBook = ABAddressBookCreateWithOptions(nil, &error).takeRetainedValue()
        ABAddressBookRequestAccessWithCompletion(addressBook,
            {(granted: Bool, error: CFError?) in
                if granted{
                    DispatchQueue.main.async {
                        var firstLoad = false
                        if let callback = self.addressBookCallback {
                            firstLoad = true
                            callback(true)
                            self.addressBookCallback = nil
                        }
                        self.saveAddressBook(addressBook, firstLoad: firstLoad)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.promptUserToChangeAddressBookSettings(false)
                        if let callback = self.addressBookCallback {
                            callback(false)
                            self.addressBookCallback = nil
                        }
                    }
                }
        })
    }
    
    func saveAddressBook (_ addressBook: ABAddressBook, firstLoad: Bool){
        
        let userPhoneNumber = User.user.phoneNumber
        
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
            
            let backgroundRealm = try! Realm()
            
            let allPeople = ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue() as NSArray
            var contacts = [String:[String:String]]()
            
            for person: ABRecord in allPeople as [AnyObject]{
                
//                guard let person = personA as? ABRecord else {
//                    return
//                }
                
                let phoneNumbers: ABMultiValue = ABRecordCopyValue(person, kABPersonPhoneProperty).takeRetainedValue() as ABMultiValue
                
                if ABMultiValueGetCount(phoneNumbers) > 0 {
                    
                    var firstName = ""
                    var lastName = ""
                    
                    if let first = ABRecordCopyValue(person, kABPersonFirstNameProperty)?.takeRetainedValue() as? String {
                        firstName = first
                    }
                    if let last = ABRecordCopyValue(person, kABPersonLastNameProperty)?.takeRetainedValue() as? String {
                        lastName = last
                    }
                    
                    if firstName+lastName != "" {
                        let phoneNumber = ABMultiValueCopyValueAtIndex(phoneNumbers, 0).takeUnretainedValue() as! NSString
                        let formattedNumber = self.formatPhoneNumber(phoneNumber as String)
                        contacts[formattedNumber] = ["firstName":firstName, "lastName":lastName]
                    }
                }
            }
            
            try! backgroundRealm.write() {
                for (k, v) in contacts {
                    if k == userPhoneNumber {
                        DispatchQueue.main.async {
                            try! realm.write() {
                                if v["firstName"] != "Me" && v["firstName"] != "me" && v["firstName"] != "" {
                                    User.user.firstName = v["firstName"]!
                                }
                                if v["lastName"] != "" {
                                    User.user.lastName = v["lastName"]!
                                }
                            }
                        }
                    } else {
                        if let friend = backgroundRealm.objects(Friend.self).filter("phoneNumber='"+k+"'").first {
                            friend.firstName = v["firstName"]!
                            friend.lastName = v["lastName"]!
                        } else {
                            let newFriend = Friend()
                            newFriend.phoneNumber = k
                            newFriend.firstName = v["firstName"]!
                            newFriend.lastName = v["lastName"]!
                            backgroundRealm.add(newFriend)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.checkName()
                try! realm.write() {
                    User.user.addressBookLoaded = true
                    if firstLoad {
                        self.determineBestAndRecentFriends()
                    }
                }
            }
        })
    }
    
    func determineBestAndRecentFriends() { //Called from within realm write block
        if User.user.lastUpdated != 0 {
            let inboxSongs = realm.objects(InboxSong.self)
            for song in inboxSongs {
                var friendNumber = song["sender"]! as! String
                if friendNumber == User.user.phoneNumber {
                    friendNumber = song["recipient"]! as! String
                }
                let shareDate = song["date"]! as! Int
                if let friend = realm.objects(Friend.self).filter("phoneNumber == %@", friendNumber).first {
                    if shareDate > friend.lastShared {
                        friend.lastShared = shareDate
                    }
                    friend.numShared += 1
                } else {
                    let newFriend = Friend()
                    newFriend.phoneNumber = friendNumber
                    newFriend.firstName = friendNumber
                    newFriend.lastName = ""
                    newFriend.lastShared = shareDate
                    newFriend.numShared = 1
                    realm.add(newFriend)
                }
            }
        }
    }
    
    func formatPhoneNumber(_ number: String) -> String {
        
        let arr = number.components(separatedBy: CharacterSet(charactersIn: "+1234567890").inverted)
        var phoneNumber = arr.joined(separator: "")

        if phoneNumber.range(of: "+") == nil {
            if let phoneInt = Int(phoneNumber) {
                phoneNumber = String(phoneInt) //Remove leading 0's
            }
            
            if let startIndex = phoneNumber.range(of: self.localDialingCode)?.lowerBound {
                if startIndex == phoneNumber.startIndex {
                    phoneNumber = "+" + phoneNumber
                } else {
                    phoneNumber = ("+" + self.localDialingCode) + phoneNumber
                }
            } else {
                phoneNumber = ("+" + self.localDialingCode) + phoneNumber
            }
        }
        return phoneNumber
    }
    
    func setLocalDialingCode() {
        var myDict: NSDictionary?
        if let path = Bundle.main.path(forResource: "DialingCodes", ofType: "plist") {
            myDict = NSDictionary(contentsOfFile: path)
        }
        if let dict = myDict {
            if let countryCode = (Locale.current as NSLocale).object(forKey: NSLocale.Key.countryCode) as? String {
                let callingCode = dict[countryCode.lowercased()]! as! String
                self.localDialingCode = callingCode
            }
        }
    }
    
    func checkName() {
        if User.user.firstName+User.user.lastName == "" {
            self.requestName("Name")
        } else if User.user.firstName == "" {
            self.requestName("First Name")
        } else if User.user.lastName == "" {
            self.requestName("Last Name")
        }
    }
    
    func requestName(_ nameType: String) {
        let alertController = UIAlertController(title: "Enter "+nameType, message: nil, preferredStyle: UIAlertControllerStyle.alert)
        alertController.addTextField { textField in
            switch (nameType) {
            case "First Name":
                textField.placeholder = "First Name"
            case "Last Name":
                textField.placeholder = "Last Name"
            default:
                textField.placeholder = "First Last"
            }
            textField.autocapitalizationType = UITextAutocapitalizationType.words
        }
        alertController.addAction(
            UIAlertAction(title: "Save", style: UIAlertActionStyle.default, handler: { UIAlertAction in
                if let textField = alertController.textFields?[0] {
                    if textField.text != "" {
                        try! realm.write() {
                            switch (nameType) {
                            case "First Name":
                                User.user.firstName = textField.text!
                            case "Last Name":
                                User.user.lastName = textField.text!
                            default:
                                if textField.text == "" {
                                    //Need better handling of this! maybe just re-request?
                                    User.user.firstName = User.user.phoneNumber
                                } else {
                                    let name = textField.text!.components(separatedBy: " ")
                                    User.user.firstName = name[0]
                                    if name.count > 1 {
                                        User.user.lastName = name[1]
                                    }
                                }
                            }
                        }
                    }
                }
            })
        )
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
    
    func enablePush (_ callback: @escaping ()->Void){
        self.pushCallback = callback
        let type: UIUserNotificationType = [UIUserNotificationType.badge, UIUserNotificationType.alert, UIUserNotificationType.sound];
        let setting = UIUserNotificationSettings(types: type, categories: nil);
        UIApplication.shared.registerUserNotificationSettings(setting);
        UIApplication.shared.registerForRemoteNotifications();
    }
    
    func pushEnabled(_ deviceToken: Data){
        try! realm.write() {
            User.user.pushToken = deviceToken.description
                .trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                .replacingOccurrences(of: " ", with: "" )
        }
        Server.server.sendPushToken()
        if let pushCallback = self.pushCallback {
            pushCallback()
            self.pushCallback = nil
        }
    }
    
    func pushDisabled(){
        if let pushCallback = self.pushCallback {
            self.promptUserToChangePushNotificationSettings() //Only do this when you're first enabling push
            pushCallback()
            self.pushCallback = nil
        }
    }
    
    func promptUserToChangePushNotificationSettings() {
        let alertController = UIAlertController(title: "Push Notifications", message: "We recommend turning push notifications on in order to use the app. Tap go to enable push notifications in settings.", preferredStyle: UIAlertControllerStyle.alert)
        alertController.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.cancel, handler:nil))
        alertController.addAction(
            UIAlertAction(title: "Go", style: UIAlertActionStyle.default, handler: { UIAlertAction in
                UIApplication.shared.openURL(URL(string: UIApplicationOpenSettingsURLString)!)
            })
        )
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
}
