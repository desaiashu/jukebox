//
//  AppDelegate.swift
//  jukebox
//
//  Created by Ashutosh Desai on 8/1/15.
//  Copyright (c) 2015 Ashutosh Desai. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import RealmSwift

public let realm = Realm()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        Fabric.with([Crashlytics()])
        SongPlayer.enableBackgroundAudio()
        
        if let user = realm.objects(User).first {
            User.user = user
            if user.addressBookLoaded {
                Permissions.checkName()
                Permissions.loadAddressBook()
            } else {
                self.presentPermissions()
            }
        } else {
            self.presentAuthentication()
        }
        
        return true
    }

    func applicationDidBecomeActive(application: UIApplication) {
        Server.sendSongs() //In case sending previously failed, might move this to willResignActive?
        Server.checkVersion()
        
        let navigationController = window?.rootViewController as! UINavigationController
        if let inboxViewController = navigationController.topViewController as? InboxViewController {
            inboxViewController.downloadData()
        }
    }
    
    func presentAuthentication() {
        let welcomeViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("WelcomeViewController") as! UIViewController
        let navigationController = UINavigationController(rootViewController: welcomeViewController)
        navigationController.navigationBarHidden = true
        window?.rootViewController = navigationController
    }
    
    func presentCore() {
        let coreNavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("CoreNavigationController") as! UINavigationController
        window?.rootViewController = coreNavigationController
        if let inboxViewController = coreNavigationController.topViewController as? InboxViewController {
            inboxViewController.downloadData()
        }
    }
    
    func presentPermissions() {
        let permissionsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("PermissionsViewController") as! UIViewController
        let navigationController = UINavigationController(rootViewController: permissionsViewController)
        navigationController.navigationBarHidden = true
        window?.rootViewController = navigationController
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Permissions.pushEnabled(deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        Permissions.pushDisabled()
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject]) {
        self.handlePush(userInfo)
        //Display notification (eg "listen") while app in foreground?
        println("push in app")
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        self.handlePush(userInfo)
        println("push out of app - fetching")
    }
    
    func handlePush(userInfo: [NSObject: AnyObject]) {
        if let pushData = userInfo as? [String:AnyObject] {
            Server.cachePushData(pushData)
            let navigationController = window?.rootViewController as! UINavigationController
            if let inboxViewController = navigationController.topViewController as? InboxViewController {
                inboxViewController.tableView.reloadData()
                println("reloaded table")
            }
        }
    }
}

