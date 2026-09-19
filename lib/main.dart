import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/disputes_screen.dart';
import 'screens/verification_list_screen.dart';
import 'screens/wallet_requests_screen.dart';
import 'screens/support_requests_screen.dart';
import 'screens/sub_admin_requests_screen.dart';

class AppColors {
  static const bg = Color(0xFF0B0B10);
  static const surface = Color(0xFF15151C);
  static const fieldFill = Color(0xFF1A1A22);
  static const border = Color(0xFF2C2C36);
  static const hint = Color(0xFF8E8E99);
  static const primary = Color(0xFF6C4CF1);
  static const white = Colors.white;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyGameAdminApp());
}

/// Routes a tapped (or foreground-received) push notification to the
/// relevant admin screen, based on the `type` / `relatedId` data payload
/// sent by the backend's notifyUser() -> sendPushNotification().
void handleNotificationNavigation(RemoteMessage message) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  final type = message.data['type']?.toString() ?? '';
  final relatedId = message.data['relatedId']?.toString();
  final hasRelatedId = relatedId != null && relatedId.isNotEmpty;

  switch (type) {
    case 'admin_new_order':
    case 'admin_alert': // legacy fallback for older order/dispute pushes
      if (hasRelatedId) {
        nav.push(MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: int.parse(relatedId))));
      } else {
        nav.push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
      }
      break;
    case 'admin_new_dispute':
    case 'dispute_raised':
      nav.push(MaterialPageRoute(builder: (_) => const DisputesScreen()));
      break;
    case 'admin_new_verification':
      nav.push(MaterialPageRoute(builder: (_) => const VerificationListScreen()));
      break;
    case 'admin_new_topup':
    case 'admin_new_withdrawal':
      nav.push(MaterialPageRoute(builder: (_) => const WalletRequestsScreen()));
      break;
    case 'admin_new_support':
      nav.push(MaterialPageRoute(builder: (_) => const SupportRequestsScreen()));
      break;
    case 'admin_new_subadmin_request':
      nav.push(MaterialPageRoute(builder: (_) => const SubAdminRequestsScreen()));
      break;
    default:
      // Unknown type — stay put, nothing to route to.
      break;
  }
}

class MyGameAdminApp extends StatelessWidget {
  const MyGameAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MYGame Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bg,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.fieldFill,
          labelStyle: const TextStyle(color: AppColors.hint),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) {
        await ApiService.saveFcmToken(token);
      }

      messaging.onTokenRefresh.listen((newToken) async {
        await ApiService.saveFcmToken(newToken);
      });

      // Notification tapped while app was backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen(handleNotificationNavigation);

      // App was fully closed and launched by tapping a notification.
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(initialMessage);
        });
      }

      // Show a quick banner if a push arrives while the app is open.
      FirebaseMessaging.onMessage.listen((message) {
        final ctx = navigatorKey.currentContext;
        final notif = message.notification;
        if (ctx == null || notif == null) return;
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('${notif.title ?? ''}: ${notif.body ?? ''}'),
            action: SnackBarAction(label: 'Open', onPressed: () => handleNotificationNavigation(message)),
            duration: const Duration(seconds: 5),
          ),
        );
      });
    } catch (_) {}
  }

  Future<void> _check() async {
    final token = await ApiService.getToken();
    final loggedIn = token != null;
    if (loggedIn) await _setupFcm();
    setState(() {
      _loggedIn = loggedIn;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return _loggedIn ? const DashboardScreen() : const LoginScreen();
  }
}
