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
        
        if let user = realm.objects(User).first {
            User.user = user
            if !user.addressBookLoaded {
                self.presentPermissions()
            }
        } else {
            self.presentAuthentication()
        }
        
        return true
    }

    func applicationDidBecomeActive(application: UIApplication) {
        Server.server.checkVersion()
        
        if let user = realm.objects(User).first {
            Server.server.sendSongs() //In case sending previously failed, might move this to willResignActive?
            if user.addressBookLoaded {
                Permissions.permissions.loadAddressBook()
            }
        }
        
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
    
    override func remoteControlReceivedWithEvent(event: UIEvent) {
        SongPlayer.songPlayer.remoteControlReceivedWithEvent(event)
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Permissions.permissions.pushEnabled(deviceToken)
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        Permissions.permissions.pushDisabled()
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject: AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        self.handlePush(userInfo)
        if let badge = userInfo["aps"]?["badge"] as? Int {
            application.applicationIconBadgeNumber = badge
        }
        completionHandler(UIBackgroundFetchResult.NewData)
    }
    
    func handlePush(userInfo: [NSObject: AnyObject]) {
        if var pushData = userInfo as? [String:AnyObject] {
            pushData["aps"] = nil
            Server.server.cachePushData(pushData)
            let navigationController = window?.rootViewController as! UINavigationController
            if let inboxViewController = navigationController.topViewController as? InboxViewController {
                inboxViewController.tableView.reloadData()
            }
        }
    }
}

