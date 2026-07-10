import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/analytics_service.dart';
export '../../services/analytics_service.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/onboarding_screen.dart';
import '../../screens/auth/email_verification_screen.dart';
import '../../screens/auth/worker_profile_setup_screen.dart';
import '../../screens/user/user_home_screen.dart';
import '../../screens/user/worker_listing_screen.dart';
import '../../screens/user/worker_profile_screen.dart';
import '../../screens/user/booking_screen.dart';
import '../../screens/user/booking_confirmation_screen.dart';
import '../../screens/user/my_bookings_screen.dart';
import '../../screens/user/booking_detail_screen.dart';
import '../../screens/user/rating_screen.dart';
import '../../screens/user/chat_screen.dart';
import '../../screens/user/notifications_screen.dart';
import '../../screens/user/user_profile_screen.dart';
import '../../screens/user/edit_profile_screen.dart';
import '../../screens/worker/worker_dashboard_screen.dart';
import '../../screens/worker/incoming_requests_screen.dart';
import '../../screens/worker/worker_booking_history_screen.dart';
import '../../screens/worker/worker_booking_detail_screen.dart';
import '../../screens/worker/worker_profile_manage_screen.dart';
import '../../screens/worker/worker_earnings_screen.dart';
import '../../screens/worker/worker_chat_list_screen.dart';
import '../../screens/worker/worker_notifications_screen.dart';
import '../../screens/worker/worker_reviews_screen.dart';
import '../../screens/worker/availability_slots_screen.dart';
import '../../screens/worker/worker_verification_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/user_management_screen.dart';
import '../../screens/admin/worker_management_screen.dart';
import '../../screens/admin/booking_management_screen.dart';
import '../../screens/admin/category_management_screen.dart';
import '../../screens/admin/area_management_screen.dart';
import '../../screens/admin/review_moderation_screen.dart';
import '../../screens/admin/notification_broadcast_screen.dart';
import '../../screens/admin/app_config_screen.dart';
import '../../screens/admin/reports_screen.dart';
import '../../screens/admin/admin_settings_screen.dart';
import '../../screens/admin/support_tickets_screen.dart';
import '../../screens/maintenance_screen.dart';
import '../../screens/notification_prefs_screen.dart';

final _supabase = Supabase.instance.client;
final analyticsService = AnalyticsService();

final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => analyticsService);

GoRouter? globalRouter;

class _AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _trackRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _trackRoute(previousRoute);
  }

  void _trackRoute(Route<dynamic> route) {
    final name = route.settings.name ?? route.settings.toString();
    analyticsService.trackScreenView(name);
  }
}

final _analyticsObserver = _AnalyticsNavigatorObserver();

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    observers: [_analyticsObserver],
    refreshListenable: GoRouterRefreshStream(_supabase.auth.onAuthStateChange),
    redirect: (context, state) async {
      final session = _supabase.auth.currentSession;
      final isLoggedIn = session != null;
      final path = state.matchedLocation;
      final isAuthRoute = path.startsWith('/login') ||
          path.startsWith('/register') ||
          path.startsWith('/onboarding') ||
          path.startsWith('/splash') ||
          path.startsWith('/email-verification') ||
          path.startsWith('/worker-profile-setup');

      if (path == '/splash') return null;

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        final isAdminEmail = session.user.email == 'ramim123@gmail.com';
        final role = await _getRole(session.user.id);
        if (isAdminEmail || role == 'admin') return '/admin-shell';
        return _routeForRole(role);
      }

      if (isLoggedIn) {
        try {
          final isAdminEmail = session.user.email == 'ramim123@gmail.com';
          final profile = await _supabase
              .from('profiles')
              .select('role, is_active')
              .eq('id', session.user.id)
              .single();

          if (profile['is_active'] == false && !isAdminEmail) {
            await _supabase.auth.signOut();
            return '/login';
          }

          final dbRole = profile['role'] as String;
          final role = isAdminEmail ? 'admin' : dbRole;

          final config = await _supabase
              .from('app_config')
              .select('value')
              .eq('key', 'maintenance_mode')
              .maybeSingle();
          if (config != null && config['value'] == 'true' && role != 'admin') {
            return '/maintenance';
          }

          // Admin routing logic: instantly override and redirect to admin panel
          if (role == 'admin') {
            if (!path.startsWith('/admin-shell')) {
              return '/admin-shell';
            }
            return null; // allow navigation within admin-shell
          }

          // Route guards: protect admin panel from non-admins
          if (path.startsWith('/admin-shell') && role != 'admin') {
            return '/login';
          }

          if (path == '/shell') {
            if (role == 'user') return null;
            if (role != 'worker') return _routeForRole(role);
            // If role == 'worker', let it fall through to the mode check below
          }
          if (path == '/worker-shell') {
            if (role == 'worker') return null;
            return _routeForRole(role);
          }

          if (path.startsWith('/shell') && role == 'worker') {
            final workerData = await _supabase
                .from('workers')
                .select('mode')
                .eq('profile_id', session.user.id)
                .maybeSingle();
            final mode = workerData?['mode'] as String? ?? 'providing';
            if (mode == 'seeking') return null;
            return '/worker-shell';
          }

          if (path.startsWith('/shell') && role != 'user' && role != 'worker') {
            return _routeForRole(role);
          }
          if (path.startsWith('/worker-shell') && role != 'worker') {
            return _routeForRole(role);
          }
        } catch (_) {
          // If network fails during redirect checks, allow navigation to proceed
          // RLS and screen-level error boundaries will handle actual data failures
          return null;
        }
      }
      return null;
    },
    routes: [
      GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (_, __) => const SplashScreen()),
      GoRoute(
          path: '/maintenance',
          name: 'maintenance',
          builder: (_, __) => const MaintenanceScreen()),
      GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/register',
          name: 'register',
          builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/email-verification',
          name: 'emailVerification',
          builder: (_, __) => const EmailVerificationScreen()),
      GoRoute(
          path: '/worker-profile-setup',
          name: 'workerProfileSetup',
          builder: (_, state) => WorkerProfileSetupScreen(
                workerId: state.extra as String?,
              )),
      GoRoute(
        path: '/shell',
        name: 'userHome',
        builder: (_, __) => const UserHomeScreen(),
        routes: [
          GoRoute(
              path: 'workers',
              name: 'workerListing',
              builder: (_, state) => WorkerListingScreen(
                    categoryId: state.uri.queryParameters['category'],
                    searchQuery: state.uri.queryParameters['search'],
                  )),
          GoRoute(
              path: 'workers/:id',
              name: 'workerProfile',
              builder: (_, state) => WorkerProfileScreen(
                    workerId: state.pathParameters['id']!,
                  )),
          GoRoute(
              path: 'book',
              name: 'booking',
              redirect: (context, state) {
                if (state.extra == null) return '/shell/workers';
                return null;
              },
              builder: (_, state) => BookingScreen(
                    workerId: state.extra as String? ?? '',
                  )),
          GoRoute(
              path: 'book/confirm',
              name: 'bookingConfirmation',
              builder: (_, state) => BookingConfirmationScreen(
                    bookingData: state.extra as Map<String, dynamic>?,
                  )),
          GoRoute(
              path: 'bookings',
              name: 'myBookings',
              builder: (_, __) => const MyBookingsScreen()),
          GoRoute(
              path: 'bookings/:id',
              name: 'bookingDetail',
              builder: (_, state) => BookingDetailScreen(
                    bookingId: state.pathParameters['id']!,
                  )),
          GoRoute(
              path: 'rate/:bookingId/:workerId',
              name: 'rating',
              builder: (_, state) => RatingScreen(
                    bookingId: state.pathParameters['bookingId']!,
                    workerId: state.pathParameters['workerId']!,
                  )),
          GoRoute(
              path: 'chat/:chatId',
              name: 'chat',
              builder: (_, state) => ChatScreen(
                    chatId: state.pathParameters['chatId']!,
                  )),
          GoRoute(
              path: 'notifications',
              name: 'userNotifications',
              builder: (_, __) => const UserNotificationsScreen()),
          GoRoute(
              path: 'profile',
              name: 'userProfile',
              builder: (_, __) => const UserProfileScreen()),
          GoRoute(
              path: 'profile/edit',
              name: 'editProfile',
              builder: (_, __) => const EditProfileScreen()),
          GoRoute(
              path: 'notifications/prefs',
              name: 'notificationPrefs',
              builder: (_, __) => const NotificationPrefsScreen()),
        ],
      ),
      GoRoute(
        path: '/worker-shell',
        name: 'workerDashboard',
        builder: (_, __) => const WorkerDashboardScreen(),
        routes: [
          GoRoute(
              path: 'requests',
              name: 'incomingRequests',
              builder: (_, __) => const IncomingRequestsScreen()),
          GoRoute(
              path: 'history',
              name: 'workerBookingHistory',
              builder: (_, state) => WorkerBookingHistoryScreen(
                    initialStatus: state.uri.queryParameters['status'],
                  )),
          GoRoute(
              path: 'bookings/:id',
              name: 'workerBookingDetail',
              builder: (_, state) => WorkerBookingDetailScreen(
                    bookingId: state.pathParameters['id']!,
                  )),
          GoRoute(
              path: 'profile',
              name: 'workerProfileManage',
              builder: (_, __) => const WorkerProfileManageScreen()),
          GoRoute(
              path: 'earnings',
              name: 'workerEarnings',
              builder: (_, __) => const WorkerEarningsScreen()),
          GoRoute(
              path: 'reviews',
              name: 'workerReviews',
              builder: (_, __) => const WorkerReviewsScreen()),
          GoRoute(
              path: 'chats',
              name: 'workerChatList',
              builder: (_, __) => const WorkerChatListScreen()),
          GoRoute(
              path: 'notifications',
              name: 'workerNotifications',
              builder: (_, __) => const WorkerNotificationsScreen()),
          GoRoute(
              path: 'notifications/prefs',
              name: 'notificationPrefsWorker',
              builder: (_, __) => const NotificationPrefsScreen()),
          GoRoute(
              path: 'availability',
              name: 'availabilitySlots',
              builder: (_, __) => const AvailabilitySlotsScreen()),
          GoRoute(
              path: 'verification',
              name: 'workerVerification',
              builder: (_, __) => const WorkerVerificationScreen()),
          GoRoute(
              path: 'worker/chat/:id',
              name: 'workerChat',
              builder: (_, state) => ChatScreen(
                    chatId: state.pathParameters['id']!,
                  )),
        ],
      ),
      GoRoute(
        path: '/admin-shell',
        name: 'adminDashboard',
        builder: (_, __) => const AdminDashboardScreen(),
        routes: [
          GoRoute(
              path: 'users',
              name: 'userManagement',
              builder: (_, __) => const UserManagementScreen()),
          GoRoute(
              path: 'workers',
              name: 'workerManagement',
              builder: (_, __) => const WorkerManagementScreen()),
          GoRoute(
              path: 'bookings',
              name: 'bookingManagement',
              builder: (_, __) => const BookingManagementScreen()),
          GoRoute(
              path: 'categories',
              name: 'categoryManagement',
              builder: (_, __) => const CategoryManagementScreen()),
          GoRoute(
              path: 'areas',
              name: 'areaManagement',
              builder: (_, __) => const AreaManagementScreen()),
          GoRoute(
              path: 'reviews',
              name: 'reviewModeration',
              builder: (_, __) => const ReviewModerationScreen()),
          GoRoute(
              path: 'broadcast',
              name: 'notificationBroadcast',
              builder: (_, __) => const NotificationBroadcastScreen()),
          GoRoute(
              path: 'config',
              name: 'appConfig',
              builder: (_, __) => const AppConfigScreen()),
          GoRoute(
              path: 'reports',
              name: 'reports',
              builder: (_, __) => const ReportsScreen()),
          GoRoute(
              path: 'settings',
              name: 'adminSettings',
              builder: (_, __) => const AdminSettingsScreen()),
          GoRoute(
              path: 'tickets',
              name: 'supportTickets',
              builder: (_, __) => const SupportTicketsScreen()),
        ],
      ),
    ],
  );
  globalRouter = router;
  return router;
});

Future<String> _getRole(String userId) async {
  try {
    final data = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    return data['role'] as String? ?? 'user';
  } catch (_) {
    return 'user';
  }
}

String _routeForRole(String role) {
  switch (role) {
    case 'admin':
      return '/admin-shell';
    case 'worker':
      return '/worker-shell';
    default:
      return '/shell';
  }
}
