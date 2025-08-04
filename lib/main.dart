import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'admin/admin_login_screen.dart';
import 'admin/admin_screen.dart';
import 'admin/admin_orders_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تهيئة OneSignal مع إعدادات متقدمة
  await _initializeOneSignal();

  // تهيئة Firebase Messaging
  await _initializeFirebaseMessaging();

  runApp(const MyApp());
}

Future<void> _initializeOneSignal() async {
  OneSignal.initialize("f041fd58-f89d-45d0-9962-bc441311f0ab");
  OneSignal.Notifications.requestPermission(true);
  OneSignal.User.addTagWithKey("user_type", "admin");

  OneSignal.Notifications.addClickListener((event) {
    final notification = event.notification;
    debugPrint('Notification clicked: ${notification.notificationId}');
  });
}

Future<void> _setupUser(User? user) async {
  if (user == null) return;

  try {
    // الحصول على playerId من OneSignal
    final playerId = await OneSignal.User.pushSubscription.id;

    if (playerId == null) {
      debugPrint('لا يمكن الحصول على playerId من OneSignal');
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // تحديث المستخدم في Firestore
    await userRef.set({
      'oneSignalPlayerId': playerId,
      'role': 'admin', // جعل المستخدم admin إذا لم يكن موجودًا
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('تم تحديث بيانات المستخدم بنجاح');
  } catch (e) {
    debugPrint('خطأ في إعداد المستخدم: $e');
  }
}

Future<void> _initializeFirebaseMessaging() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
}

void _handleForegroundMessage(RemoteMessage message) async {
  debugPrint('Foreground message: ${message.messageId}');
  await _saveNotificationToFirestore(message);
}

void _handleMessageOpened(RemoteMessage message) async {
  debugPrint('App opened from notification: ${message.messageId}');
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await _saveNotificationToFirestore(message);
}

Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
  try {
    final notification = {
      'title': message.notification?.title ?? 'إشعار جديد',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': message.data['type'] ?? 'general',
    };

    await FirebaseFirestore.instance.collection('admin_notifications').add(notification);
  } catch (e) {
    debugPrint('Error saving notification: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talabak Express',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const RootScreen(),
      routes: {
        '/admin': (context) => const AdminScreen(),
        '/admin/orders': (context) => const AdminOrdersScreen(),
      },
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // استدعاء _setupUser عند تغيير حالة المصادقة
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _setupUser(user);
          });
          return const AdminScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}