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

public var realm: Realm!

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics()])
        
        Realm.Configuration.defaultConfiguration = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                if oldSchemaVersion < 1 { }
        })
        
        try! realm = Realm()
        
        if let user = realm.objects(User.self).first {
            User.user = user
            if !user.addressBookLoaded {
                self.presentPermissions()
            }
        } else {
            self.presentAuthentication()
        }
        
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Server.server.checkVersion()
        
        if let user = realm.objects(User.self).first {
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
        let welcomeViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "WelcomeViewController") 
        let navigationController = UINavigationController(rootViewController: welcomeViewController)
        navigationController.isNavigationBarHidden = true
        window?.rootViewController = navigationController
    }
    
    func presentCore() {
        let coreNavigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "CoreNavigationController") as! UINavigationController
        window?.rootViewController = coreNavigationController
    }
    
    func presentPermissions() {
        let permissionsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PermissionsViewController") 
        let navigationController = UINavigationController(rootViewController: permissionsViewController)
        navigationController.isNavigationBarHidden = true
        window?.rootViewController = navigationController
        Server.server.downloadInbox({})
    }
    
    override func remoteControlReceived(with event: UIEvent?) {
        SongPlayer.songPlayer.remoteControlReceivedWithEvent(event)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Permissions.permissions.pushEnabled(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Permissions.permissions.pushDisabled()
    }
    
    private func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: AnyObject], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        self.handlePush(userInfo)
        if let badge = userInfo["aps"]?["badge"] as? Int {
            application.applicationIconBadgeNumber = badge
        }
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func handlePush(_ userInfo: [AnyHashable: Any]) {
        if var pushData = userInfo as? [String:AnyObject] {
            pushData["aps"] = nil
            Server.server.cachePushData(pushData)
        }
    }
}

