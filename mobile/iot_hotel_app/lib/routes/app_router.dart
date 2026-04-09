import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/reception/dashboard_page.dart';
import '../pages/guest/main_shell_page.dart';
import '../pages/guest/hotel_list_page.dart';
import '../pages/guest/hotel_detail_page.dart';
import '../pages/guest/booking_flow_page.dart';
import '../pages/guest/order_list_page.dart';
import '../pages/guest/order_detail_page.dart';
import '../pages/guest/favorites_page.dart';
import '../pages/guest/online_checkin_page.dart';
import '../pages/guest/notification_center_page.dart';
import '../pages/guest/review_submit_page.dart';
import '../pages/guest/checkout_page.dart';
import '../pages/guest/coupon_center_page.dart';
import '../pages/guest/extend_stay_page.dart';
import '../pages/guest/frequent_guest_page.dart';
import '../pages/guest/personal_info_page.dart';
import '../services/auth_service.dart';
import '../core/auth/auth_state_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggedIn = await authService.isLoggedIn();
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final currentPath = state.matchedLocation;

      final publicPaths = ['/', '/hotel-list', '/hotel-detail', '/login', '/register'];

      if (!isLoggedIn && !publicPaths.any((p) => currentPath == p || currentPath.startsWith('$p/'))) {
        if (currentPath != '/login') return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainShellPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
      GoRoute(path: '/reception', builder: (context, state) => const ReceptionDashboardPage()),
      GoRoute(path: '/hotel-list', builder: (context, state) => const HotelListPage()),
      GoRoute(
        path: '/hotel-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return HotelDetailPage(hotelId: extra['hotelId']);
        },
      ),
      GoRoute(
        path: '/booking-flow',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BookingFlowPage(
            hotelName: extra['hotelName'] ?? '智联旗舰店',
            roomType: extra['roomType'] ?? '标准间',
            price: extra['price'] ?? 0.0,
            roomId: extra['roomId'] ?? 0,
            checkInDate: extra['checkInDate'] ?? DateTime.now(),
            checkOutDate: extra['checkOutDate'] ?? DateTime.now().add(const Duration(days: 1)),
          );
        },
      ),
      GoRoute(path: '/orders', builder: (context, state) => const OrderListPage()),
      GoRoute(
        path: '/order-detail/:orderId',
        builder: (context, state) {
          final orderId = int.tryParse(state.pathParameters['orderId'] ?? '0') ?? 0;
          return OrderDetailPage(orderId: orderId);
        },
      ),
      GoRoute(path: '/favorites', builder: (context, state) => const FavoritesPage()),
      GoRoute(
        path: '/online-checkin',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OnlineCheckinPage(bookingId: extra['bookingId'] as int?);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/review-submit',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ReviewSubmitPage(
            bookingId: extra['bookingId'] as int? ?? 0,
            hotelId: extra['hotelId'] as int?,
            hotelName: extra['hotelName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CheckoutPage(bookingId: extra['bookingId'] as int? ?? 0);
        },
      ),
      GoRoute(
        path: '/coupons',
        builder: (context, state) => const CouponCenterPage(),
      ),
      GoRoute(
        path: '/extend-stay',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ExtendStayPage(bookingId: extra['bookingId'] as int? ?? 0);
        },
      ),
      GoRoute(
        path: '/frequent-guests',
        builder: (context, state) => const FrequentGuestPage(),
      ),
      GoRoute(
        path: '/personal-info',
        builder: (context, state) => const PersonalInfoPage(),
      ),
    ],
  );
});
