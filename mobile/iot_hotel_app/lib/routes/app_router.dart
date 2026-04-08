import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../pages/auth/login_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/device_monitor_page.dart';
import '../pages/admin/room_manage_page.dart';
import '../pages/admin/hotel_edit_page.dart';
import '../pages/admin/reports_page.dart';
import '../pages/reception/dashboard_page.dart' as reception;
import '../pages/guest/booking_page.dart';
import '../pages/guest/online_checkin_page.dart';
import '../pages/guest/room_service_page.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider((ref) => AuthService());

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final authService = ref.read(authServiceProvider);
      final isLoggedIn = await authService.isLoggedIn();
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) {
        final role = await authService.getUserRole();
        switch (role) { case 'admin': return '/admin'; case 'reception': return '/reception'; default: return '/guest'; }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminDashboardPage()),
      GoRoute(path: '/admin/devices', builder: (context, state) => const DeviceMonitorPage()),
      GoRoute(path: '/admin/rooms', builder: (context, state) => const RoomManagePage()),
      GoRoute(path: '/admin/hotel', builder: (context, state) => const HotelEditPage()),
      GoRoute(path: '/admin/reports', builder: (context, state) => const ReportsPage()),
      GoRoute(path: '/reception', builder: (context, state) => const reception.ReceptionDashboardPage()),
      GoRoute(path: '/reception/checkinout', builder: (context, state) => const reception.CheckInOutPage()),
      GoRoute(path: '/reception/bookings', builder: (context, state) => const reception.BookingsPage()),
      GoRoute(path: '/reception/rooms', builder: (context, state) => const reception.RoomAvailabilityPage()),
      GoRoute(path: '/reception/workorders', builder: (context, state) => const reception.WorkOrdersPage()),
      GoRoute(path: '/reception/delivery', builder: (context, state) => const reception.DeliveryOrdersPage()),
      GoRoute(path: '/reception/bills', builder: (context, state) => const reception.BillsPage()),
      GoRoute(path: '/guest', builder: (context, state) => const BookingPage()),
      GoRoute(path: '/guest/checkin', builder: (context, state) => const OnlineCheckInPage()),
      GoRoute(path: '/guest/service', builder: (context, state) => const RoomServicePage()),
    ],
  );
});
