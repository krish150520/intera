import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intera/main.dart';
import 'package:intera/shared/models/post_model.dart';
import 'package:intera/features/home/screens/post_detail_screen.dart';
import 'package:intera/features/messaging/screens/chat_screen.dart';
import 'package:intera/features/messaging/services/messaging_service.dart';
import 'package:intera/features/home/screens/spark_viewer_screen.dart';
import 'package:intera/features/profile/screens/user_profile_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM automatically handles background notifications if they contain a "notification" block.
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _fcm = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();



  /// Initializes FCM and Flutter Local Notifications.
  static Future<void> initialize() async {
    try {
      // 1. Request system notification permission (especially Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('User granted notification permission: ${settings.authorizationStatus}');

      // 2. Initialize Flutter Local Notifications for foreground alerts
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            try {
              final Map<String, dynamic> data = jsonDecode(details.payload!);
              handleNotificationTap(data);
            } catch (e) {
              debugPrint('Error handling local notification tap payload: $e');
            }
          }
        },
      );

      // Create Android Notification Channel
      const channel = AndroidNotificationChannel(
        'intera_default_channel',
        'INTERA Notifications',
        description: 'Real-time notifications for INTERA DMs, comments, and activities',
        importance: Importance.max,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 3. Configure FCM handlers
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Foreground Message Handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message received: ${message.messageId}');
        final notification = message.notification;
        if (notification != null) {
          showLocalNotification(
            title: notification.title ?? 'New Notification',
            body: notification.body ?? '',
            payload: jsonEncode(message.data),
          );
        }
      });

      // Background Message Tap Handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification opened from background: ${message.data}');
        handleNotificationTap(message.data);
      });

      // App Killed State Tap Handler
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Notification opened from killed state: ${initialMessage.data}');
        handleNotificationTap(initialMessage.data);
      }

      // 4. Save and listen to FCM Token updates
      _fcm.onTokenRefresh.listen((token) {
        saveFcmToken(token);
      });

      final currentToken = await _fcm.getToken();
      if (currentToken != null) {
        await saveFcmToken(currentToken);
      }
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  /// Displays a local foreground system tray notification.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'intera_default_channel',
      'INTERA Notifications',
      channelDescription: 'Real-time notifications for INTERA DMs, comments, and activities',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    const iosDetails = DarwinNotificationDetails();
    const platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      id: DateTime.now().microsecondsSinceEpoch % 2147483647,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  /// Handles custom navigation logic when a user clicks/taps on a notification payload.
  static Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    final context = InteraApp.navigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'] as String? ?? '';
    final relatedId = data['relatedId'] as String? ?? '';

    if (relatedId.isEmpty) return;

    try {
      if (type == 'post' || type == 'like' || type == 'comment') {
        // Fetch post and open PostDetailScreen
        final doc = await _db.collection('posts').doc(relatedId).get();
        if (doc.exists) {
          final post = Post.fromFirestore(doc, _auth.currentUser?.uid ?? '');
          InteraApp.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: post),
          ));
        }
      } else if (type == 'chat' || type == 'message' || type == 'messageRequest') {
        // Fetch conversation and open ChatScreen
        final doc = await _db.collection('conversations').doc(relatedId).get();
        if (doc.exists) {
          final convoData = doc.data() ?? {};
          final myUid = _auth.currentUser?.uid ?? '';
          final participants = List<String>.from(convoData['participants'] ?? []);
          final otherUid = participants.firstWhere((id) => id != myUid, orElse: () => '');
          final participantInfo = Map<String, dynamic>.from(convoData['participantInfo'] ?? {});
          final otherName = participantInfo[otherUid]?['name'] ?? 'User';
          final otherAvatar = participantInfo[otherUid]?['avatar'] ?? '';
          final status = convoData['status'] ?? 'active';

          InteraApp.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: relatedId,
              otherUid: otherUid,
              otherName: otherName,
              otherAvatar: otherAvatar,
              initialAccess: status == 'pending'
                  ? ConversationAccess.pending
                  : ConversationAccess.active,
            ),
          ));
        }
      } else if (type == 'spark' || type == 'sparkReply') {
        // Fetch target spark and build user sparks viewer group
        final doc = await _db.collection('stories').doc(relatedId).get();
        if (doc.exists) {
          final targetSpark = SparkItem.fromFirestore(doc);

          final authorSparksSnap = await _db
              .collection('stories')
              .where('authorId', isEqualTo: targetSpark.authorId)
              .get();

          final List<SparkItem> authorSparks = authorSparksSnap.docs
              .map((d) => SparkItem.fromFirestore(d))
              .toList();

          authorSparks.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          final group = SparkUserGroup(
            authorId: targetSpark.authorId,
            authorName: targetSpark.authorName,
            authorAvatar: targetSpark.authorAvatar,
            sparks: authorSparks,
          );

          InteraApp.navigatorKey.currentState?.push(PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.transparent,
            pageBuilder: (_, __, ___) => SparkViewerScreen(
              args: SparkViewerArgs(groups: [group], initialUserIndex: 0),
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ));
        }
      } else if (type == 'profile' || type == 'follow') {
        // Fetch target user and open UserProfileScreen
        final doc = await _db.collection('users').doc(relatedId).get();
        if (doc.exists) {
          final userData = doc.data() ?? {};
          final name = userData['name'] ?? 'User';
          final avatar = userData['profileImageUrl'] ?? userData['photoURL'] ?? '';

          InteraApp.navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              userId: relatedId,
              userName: name,
              userAvatar: avatar,
            ),
          ));
        }
      }
    } catch (e) {
      debugPrint('Error navigating from notification click tap: $e');
    }
  }

  /// Saves the device's FCM push token to the logged-in user's Firestore document.
  static Future<void> saveFcmToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
      });
      debugPrint('FCM Token saved to users/$uid');
    } catch (e) {
      debugPrint('Failed to save FCM token to database: $e');
    }
  }

  /// Sends an in-app notification document to Firestore.
  ///
  /// Push notifications are handled server-side. Deploy a Firebase Cloud
  /// Function that triggers on `notifications/{docId}` onCreate to read
  /// the recipient's FCM token from `users/{recipientId}.fcmToken` and
  /// send the push via the Firebase Admin SDK (FCM v1 HTTP API).
  static Future<void> sendNotification({
    required String recipientId,
    required String type,
    required String title,
    required String subtitle,
    required String relatedId,
  }) async {
    final senderId = _auth.currentUser?.uid ?? '';
    // Do not notify oneself
    if (senderId == recipientId) return;

    // Write the notification document to Firestore.
    // A Cloud Function should listen to this collection and dispatch
    // the FCM push notification server-side.
    await _db.collection('notifications').add({
      'recipientId': recipientId,
      'senderId': senderId,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Real-time stream of unread notification count for a user.
  static Stream<int> unreadCountStream(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Handles liking/unliking a post, and triggers a notification if liked.
  static Future<void> toggleLike({
    required String postId,
    required String postAuthorId,
    required String postTitle,
    required String currentUid,
    required List likedBy,
  }) async {
    if (currentUid.isEmpty) return;
    final ref = _db.collection('posts').doc(postId);
    final isLiked = likedBy.contains(currentUid);

    if (isLiked) {
      await ref.update({
        'likeCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([currentUid]),
      });
    } else {
      await ref.update({
        'likeCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([currentUid]),
      });

      // Get current user's name
      String senderName = 'Someone';
      try {
        final userDoc = await _db.collection('users').doc(currentUid).get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['name'] ?? 'Someone';
        }
      } catch (_) {}

      await sendNotification(
        recipientId: postAuthorId,
        type: 'like',
        title: '$senderName liked your post',
        subtitle: postTitle.isNotEmpty ? postTitle : 'View post details',
        relatedId: postId,
      );
    }
  }
}
