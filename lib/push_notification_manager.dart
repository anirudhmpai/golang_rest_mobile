import 'dart:convert';
import 'dart:io';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'main.dart';

class PushNotificationsManager {
  PushNotificationsManager._();

  factory PushNotificationsManager() => _instance;

  static final PushNotificationsManager _instance =
      PushNotificationsManager._();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _initialized = false;
  String savedToken = "";

  Future<void> init({required Function(String) completion}) async {
    if (!_initialized) {
      /// Local Notifications
      _initializeLocalNotificationPlugin();

      await _firebaseMessaging.requestPermission(
          sound: true, badge: true, alert: true, provisional: false);
      // _firebaseMessaging.onIosSettingsRegistered.listen((IosNotificationSettings settings) {
      //   debugPrint("Firebase Settings registered: $settings");
      // });

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true, // Required to display a heads up notification
        badge: true,
        sound: true,
      );
      try {
        await _firebaseMessaging.getToken();
        _firebaseMessaging.getToken().then((String? token) {
          debugPrint("Firebase Token: ${token!}");
          savedToken = token;
          completion(token);
        });
      } catch (error) {
        debugPrint(error.toString());
      }

      FirebaseMessaging.instance.setAutoInitEnabled(true);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        try {
          AndroidNotification? android = message.notification!.android;
          if (notification != null && android != null) {
            debugPrint("onMessage: $message");
            getPayloadData(message.data);
          } else {
            debugPrint("onMessage: $message");
            _showLocalNotification(message.data);
          }
        } catch (_) {
          _showLocalNotification(message.data);
        }
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification!.android;
        if (notification != null && android != null) {
          debugPrint("onMessageOpenedApp: $message");
          getPayloadData(message.data);
        }
      });

      _initialized = true;
    }
  }

  _initializeLocalNotificationPlugin() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    /// Note: permissions aren't requested here just to demonstrate that can be
    /// done later
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
            onDidReceiveLocalNotification:
                (int id, String? title, String? body, String? payload) async {
              debugPrint(payload);
            });

    final InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse notificationResponse) async {
      debugPrint('notification payload: $notificationResponse');
    });
  }

  _showLocalNotification(Map<String, dynamic> message) async {
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(channel.id, channel.name,
            channelDescription: channel.description,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false,
            icon: '@mipmap/ic_launcher');

    DarwinNotificationDetails darwinNotificationDetails =
        const DarwinNotificationDetails(
            presentSound: true, presentBadge: true, presentAlert: true);

    late String title;
    late String body;

    if (Platform.isAndroid) {
      title = message['title'] ?? "N/A";
      body = message['body'] ?? "N/A";
    } else if (Platform.isIOS) {
      title = message['aps']['alert']['title'] ?? "N/A";
      body = message['aps']['alert']['body'] ?? "N/A";
    }

    NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: darwinNotificationDetails);
    await flutterLocalNotificationsPlugin.show(
        1, title, body, platformChannelSpecifics,
        payload: message.toString());
  }

  Future<void> getPayloadData(Map<String, dynamic> message) async {
    debugPrint("Push Payload:\n$message");

    /// Checking if there is a user else return!
    // if (await GetStorage(AppConstants.getStorageName).read('token') == null) {
    //   return;
    // }

    // Checking if payload has data else return!
    var pushData = message;
    _checkMetaTypeAndRoute(pushData);
    // pushData['metadata'];
  }

  Future<void> logout() async {
    _firebaseMessaging.deleteToken();
    _initialized = false;
  }
}

extension on PushNotificationsManager {
  _checkMetaTypeAndRoute(dynamic pushData) {
    var metaType = json.decode(pushData['type']);
    PushNotificationMetaData metaData = _getMetaEnumForMetaType(metaType);

    // var isGroup = pushData['group_notification'] == 'true';
    // var targetID;
    // var itemID = int.parse(pushData['id']);
    // var targetID = int.parse(pushData['target_id']);

    switch (metaData) {
      case PushNotificationMetaData.userUpdate:
        // Get.snackbar('message', metaData.name);
        final snackBar = SnackBar(
          /// need to set following properties for best effect of awesome_snackbar_content
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          content: AwesomeSnackbarContent(
            title: 'On Snap!',
            message:
                'This is an example error message that will be shown in the body of snackbar!',

            /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
            contentType: ContentType.failure,
          ),
        );

        ScaffoldMessenger.of(scaffoldMessengerKey!.currentState!.context)
          ..hideCurrentSnackBar()
          ..showSnackBar(snackBar);
        _notificationNavigation();
        try {
          // Get.find<ExplorerController>()
          //   ..fetchJobs()
          //   ..update();
        } catch (_) {}
        break;

      case PushNotificationMetaData.message:
        _messageOrInvitation(0, 0);
        break;
    }
  }

  PushNotificationMetaData _getMetaEnumForMetaType(int type) {
    PushNotificationMetaData metaData = PushNotificationMetaData.userUpdate;

    switch (type) {
      case 1:
        metaData = PushNotificationMetaData.userUpdate;
        break;
      case 2:
        metaData = PushNotificationMetaData.message;
        break;
    }

    return metaData;
  }

  _messageOrInvitation(int itemID, int targetID) {
    // Get.toNamed(Routes.chat);
  }

  _notificationNavigation() {
    // Get.toNamed(Routes.notifications);
  }
}

/// PushNotificationMetaData
enum PushNotificationMetaData {
  userUpdate,
  message,
}

extension PushNotificationMetaDataValues on PushNotificationMetaData {
  int get intValue {
    int intValue = 1;

    switch (this) {
      case PushNotificationMetaData.userUpdate:
        intValue = 1;
        break;
      case PushNotificationMetaData.message:
        intValue = 2;
        break;
    }

    return intValue;
  }
}
