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
import '../services/auth_service.dart';

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
        final userRole = await authService.getUserRole();
        switch (userRole) {
          case 'admin':
            return '/admin';
          case 'staff':
            return '/reception';
          default:
            return '/';
        }
      }

      if (isLoggedIn && !isLoggingIn) {
        final userRole = await authService.getUserRole();
        final currentPath = state.matchedLocation;

        if (userRole == 'admin' && currentPath != '/admin' && !currentPath.startsWith('/admin')) {
          return '/admin';
        }
        if (userRole == 'staff' && currentPath != '/reception' && !currentPath.startsWith('/reception')) {
          return '/reception';
        }
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
    ],
  );
});
