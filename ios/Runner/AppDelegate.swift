import UIKit
import Flutter
import GoogleMaps
import Firebase
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var flutterChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Firebase first
    FirebaseApp.configure()
    print("[APNS Debug] Firebase configured")
    
    // Set up method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      flutterChannel = FlutterMethodChannel(
        name: "com.flockbusiness/notifications",
        binaryMessenger: controller.binaryMessenger
      )
    }
    
    // Set up notifications for iOS 10+
    if #available(iOS 10.0, *) {
      print("[APNS Debug] Setting up notifications for iOS 10+")
      let center = UNUserNotificationCenter.current()
      center.delegate = self
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
      center.requestAuthorization(options: authOptions) { granted, error in
        if let error = error {
          print("[APNS Debug] Error requesting authorization: \(error.localizedDescription)")
          return
        }
        
        print("[APNS Debug] Authorization granted: \(granted)")
        if granted {
          DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            
            // Get and log current settings
            center.getNotificationSettings { settings in
              print("[APNS Debug] Authorization status: \(settings.authorizationStatus.rawValue)")
              print("[APNS Debug] Alert setting: \(settings.alertSetting.rawValue)")
              print("[APNS Debug] Badge setting: \(settings.badgeSetting.rawValue)")
              print("[APNS Debug] Sound setting: \(settings.soundSetting.rawValue)")
              print("[APNS Debug] Notification center setting: \(settings.notificationCenterSetting.rawValue)")
              print("[APNS Debug] Lock screen setting: \(settings.lockScreenSetting.rawValue)")
            }
          }
        }
      }
    }
    
    // Set FCM delegate
    Messaging.messaging().delegate = self
    
    // Register for remote notifications
    application.registerForRemoteNotifications()
    
    GMSServices.provideAPIKey("AIzaSyA4D0ULsoSN1GhRqCcL0JtnyUnpLPDX1Do")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle APNs token
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("[APNS Debug] Received APNS token")
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("[APNS Debug] APNS token: \(token)")
    
    // Set APNS token for FCM
    Messaging.messaging().apnsToken = deviceToken
    
    // Get FCM token with retry
    var retryCount = 0
    let maxRetries = 3
    
    func tryGetToken() {
      Messaging.messaging().token { token, error in
        if let error = error {
          print("[APNS Debug] Error fetching FCM token: \(error.localizedDescription)")
          if retryCount < maxRetries {
            retryCount += 1
            print("[APNS Debug] Retrying FCM token fetch... Attempt \(retryCount)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              tryGetToken()
            }
          }
          return
        }
        
        if let token = token {
          print("[APNS Debug] FCM token successfully retrieved: \(token)")
          self.flutterChannel?.invokeMethod(
            "onFCMTokenReceived",
            arguments: ["token": token]
          )
        } else {
          print("[APNS Debug] FCM token is nil")
          if retryCount < maxRetries {
            retryCount += 1
            print("[APNS Debug] Retrying FCM token fetch... Attempt \(retryCount)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              tryGetToken()
            }
          }
        }
      }
    }
    
    // Start the token retrieval process
    tryGetToken()
  }
  
  // Handle registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("[APNS Debug] Failed to register for remote notifications: \(error.localizedDescription)")
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("[APNS Debug] FCM token refreshed: \(fcmToken ?? "nil")")
    
    if let token = fcmToken {
      flutterChannel?.invokeMethod(
        "onFCMTokenRefreshed",
        arguments: ["token": token]
      )
    }
  }
}

// MARK: - UNUserNotificationCenter Methods
extension AppDelegate {
  // Handle foreground notifications
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("[APNS Debug] Received notification in foreground: \(userInfo)")
    
    // For iOS 10+, we need to specify presentation options
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  // Handle notification response
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("[APNS Debug] User responded to notification: \(userInfo)")
    
    // Pass notification data to Flutter
    if let jsonData = try? JSONSerialization.data(withJSONObject: userInfo),
       let jsonString = String(data: jsonData, encoding: .utf8) {
      flutterChannel?.invokeMethod(
        "onNotificationTapped",
        arguments: ["notification": jsonString]
      )
    }
    
    completionHandler()
  }
  
  // Handle silent notifications
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("[APNS Debug] Received silent notification: \(userInfo)")
    
    if let aps = userInfo["aps"] as? [String: Any] {
      print("[APNS Debug] APS content: \(aps)")
    }
    
    if let messageID = userInfo["gcm.message_id"] {
      print("[APNS Debug] Message ID: \(messageID)")
    }
    
    completionHandler(.newData)
  }
}