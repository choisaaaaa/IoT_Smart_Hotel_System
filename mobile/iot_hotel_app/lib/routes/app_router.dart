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
import '../services/auth_service.dart';
import '../services/booking_service.dart';
import '../services/device_service.dart';
import '../services/member_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final bookingServiceProvider = Provider((ref) => BookingService());
final deviceServiceProvider = Provider((ref) => DeviceService());
final memberServiceProvider = Provider((ref) => MemberService());

final routerProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggedIn = await authService.isLoggedIn();
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
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
      GoRoute(path: '/hotel-detail', builder: (context, state) => const HotelDetailPage()),
      GoRoute(
        path: '/booking-flow', 
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BookingFlowPage(
            hotelName: extra['hotelName'] ?? '智联旗舰店',
            roomType: extra['roomType'] ?? '标准间',
            price: extra['price'] ?? 0.0,
            roomId: extra['roomId'] ?? 0,
          );
        },
      ),
      GoRoute(path: '/orders', builder: (context, state) => const OrderListPage()),
    ],
  );
});
