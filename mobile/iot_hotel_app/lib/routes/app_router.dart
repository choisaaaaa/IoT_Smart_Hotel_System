import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../pages/auth/login_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/reception/dashboard_page.dart';
import '../pages/guest/main_shell_page.dart';
import '../pages/guest/hotel_list_page.dart';
import '../pages/guest/hotel_detail_page.dart';
import '../pages/guest/booking_flow_page.dart';
import '../pages/guest/order_list_page.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainShellPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
      GoRoute(path: '/reception', builder: (context, state) => const ReceptionDashboardPage()),
      GoRoute(path: '/hotel-list', builder: (context, state) => const HotelListPage()),
      GoRoute(path: '/hotel-detail', builder: (context, state) => const HotelDetailPage()),
      GoRoute(path: '/booking-flow', builder: (context, state) => const BookingFlowPage()),
      GoRoute(path: '/orders', builder: (context, state) => const OrderListPage()),
    ],
  );
});
