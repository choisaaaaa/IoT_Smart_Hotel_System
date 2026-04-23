import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_observer.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/admin/dashboard_page.dart';
import '../pages/admin/environment_monitor_page.dart';
import '../pages/admin/room_type_manage_page.dart';
import '../pages/admin/floor_manage_page.dart';
import '../pages/admin/price_calendar_page.dart';
import '../pages/admin/coupon_manage_page.dart';
import '../pages/admin/user_manage_page.dart';
import '../pages/reception/dashboard_page.dart';
import '../pages/reception/checkin_out_page.dart';
import '../pages/reception/bookings_page.dart';
import '../pages/reception/device_management_page.dart';
import '../pages/reception/work_orders_page.dart';
import '../pages/reception/delivery_orders_page.dart';
import '../pages/reception/room_availability_page.dart';
import '../pages/reception/voice_calls_page.dart';
import '../pages/reception/bills_page.dart';
import '../pages/reception/price_settings_page.dart';
import '../pages/reception/environment_monitor_page.dart';
import '../pages/system/dashboard_page.dart';
import '../pages/system/system_settings_page.dart';
import '../pages/system/mqtt_manage_page.dart';
import '../pages/system/pending_devices_page.dart';
import '../pages/admin/knowledge_base_manage_page.dart';
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
import '../pages/guest/my_reviews_page.dart';
import '../pages/guest/recent_browsing_page.dart';
import '../pages/guest/hotel_reviews_page.dart';
import '../pages/guest/checkout_page.dart';
import '../pages/guest/coupon_center_page.dart';
import '../pages/guest/extend_stay_page.dart';
import '../pages/guest/frequent_guest_page.dart';
import '../pages/guest/personal_info_page.dart';
import '../pages/guest/wallet_page.dart';
import '../pages/guest/member_page.dart';
import '../pages/guest/room_service_page.dart';
import '../pages/guest/ai_butler_page.dart';
import '../pages/auth/qr_scanner_page.dart';
import '../core/auth/auth_state_notifier.dart';
import '../core/network/api_interceptor.dart';

/// 路由状态通知器，确保 GoRouter 实例稳定
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;
  RouterNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.read(routerNotifierProvider);

  return GoRouter(
    navigatorKey: AppRouter.navigatorKey,
    observers: [AppRouteObserver()],
    refreshListenable: routerNotifier,
    initialLocation: '/',
    redirect: (context, state) async {
      final authState = ref.read(authStateProvider);
      
      // 如果认证状态尚未初始化完成，不执行任何重定向逻辑，等待初始化
      if (!authState.isInitialized) {
        debugPrint('⏳ [Router Redirect] Auth not initialized, skipping...');
        return null;
      }

      final isLoggedIn = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      final currentPath = state.matchedLocation;

      debugPrint('🛡️ [Router Redirect] path: "$currentPath", isLoggedIn: $isLoggedIn, mode: ${authState.currentMode}');

      // 定义游客可访问的公开路径
      final publicPaths = [
        '/',           // 首页
        '/hotel-list', // 酒店列表
        '/hotel-detail', // 酒店详情
        '/login',      // 登录页
        '/register',   // 注册页
      ];

      // 如果未登录且访问的是公开路径，允许访问
      if (!isLoggedIn && publicPaths.any((p) => currentPath == p || currentPath.startsWith('$p/'))) {
        // 确保处于游客模式
        if (authState.currentMode != AppMode.guest) {
          ref.read(authStateProvider.notifier).switchMode(AppMode.guest);
        }
        return null;
      }

      // 如果未登录且访问的不是公开路径，重定向到首页（游客模式）
      if (!isLoggedIn && !publicPaths.any((p) => currentPath == p || currentPath.startsWith('$p/'))) {
        debugPrint('🚩 [Router] Not logged in, redirecting from "$currentPath" to "/"');
        return '/';
      }

      if (isLoggedIn && isLoggingIn) {
        debugPrint('🚩 [Router] Already logged in, redirecting from "$currentPath" to dashboard');
        switch (authState.currentMode) {
          case AppMode.system:
            return '/system';
          case AppMode.manager:
            return '/admin';
          case AppMode.reception:
            return '/reception';
          default:
            return '/';
        }
      }

      if (isLoggedIn) {
        final protectedPaths = ['/booking-flow', '/orders', '/order-detail', '/online-checkin', '/checkout', '/extend-stay', '/review-submit', '/my-reviews', '/recent-browsing', '/hotel-reviews', '/favorites', '/personal-info', '/wallet', '/coupons'];
        if (protectedPaths.any((p) => currentPath.startsWith(p)) && 
            (authState.currentMode != AppMode.guest && authState.currentMode != AppMode.customer)) {
          debugPrint('🚫 [Router Access Denied] Path "$currentPath" not allowed for mode "${authState.currentMode}"');
          return '/login';
        }

        // 根据当前模式强制跳转到对应页面
        if (currentPath == '/') {
          switch (authState.currentMode) {
            case AppMode.system:
              return '/system';
            case AppMode.manager:
              return '/admin';
            case AppMode.reception:
              return '/reception';
            default:
              break;
          }
        }

        if (currentPath.startsWith('/reception') && !authState.canSwitchTo(AppMode.reception)) {
          return '/';
        }
        if (currentPath.startsWith('/admin') && !authState.canSwitchTo(AppMode.manager)) {
          return '/';
        }
        if (currentPath.startsWith('/system') && !authState.canSwitchTo(AppMode.system)) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainShellPage()),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/qr-scanner',
        name: 'qr-scanner',
        builder: (context, state) => const QrScannerPage(),
      ),
      GoRoute(path: '/admin', name: 'admin', builder: (context, state) => const AdminDashboardPage()),
      GoRoute(path: '/system', name: 'system', builder: (context, state) => const SystemDashboardPage()),
      GoRoute(path: '/reception', name: 'reception', builder: (context, state) => const ReceptionDashboardPage()),
      GoRoute(path: '/hotel-list', name: 'hotel-list', builder: (context, state) => const HotelListPage()),
      GoRoute(
        path: '/hotel-detail',
        name: 'hotel-detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return HotelDetailPage(hotelId: extra['hotelId']);
        },
      ),
      GoRoute(
        path: '/booking-flow',
        name: 'booking-flow',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return BookingFlowPage(
            hotelName: extra['hotelName'] ?? '智联旗舰店',
            roomType: extra['roomType'] ?? '标准间',
            price: (extra['price'] as num?)?.toDouble() ?? 0.0,
            roomId: (extra['roomId'] as num?)?.toInt() ?? 0,
            hotelId: (extra['hotelId'] as num?)?.toInt() ?? 1,
            checkInDate: extra['checkInDate'] ?? DateTime.now(),
            checkOutDate: extra['checkOutDate'] ?? DateTime.now().add(const Duration(days: 1)),
            roomTypeId: (extra['roomTypeId'] as num?)?.toInt(),
          );
        },
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final tab = tabStr != null ? int.tryParse(tabStr) : null;
          return OrderListPage(initialTab: tab);
        },
      ),
      GoRoute(
        path: '/order-detail/:id',
        name: 'order-detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return OrderDetailPage(orderId: id);
        },
      ),
      GoRoute(
        path: '/favorites',
        name: 'favorites',
        builder: (context, state) => const FavoritesPage(),
      ),
      GoRoute(
        path: '/online-checkin/:id',
        name: 'online-checkin',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          final bookingId = extra?['bookingId'] as int? ?? id;
          return OnlineCheckinPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationCenterPage(),
      ),
      GoRoute(
        path: '/review-submit/:id',
        name: 'review-submit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final bookingId = extra['bookingId'] as int? ?? id;
          return ReviewSubmitPage(
            bookingId: bookingId,
            hotelId: extra['hotelId'] as int?,
            hotelName: extra['hotelName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/my-reviews',
        name: 'my-reviews',
        builder: (context, state) => const MyReviewsPage(),
      ),
      GoRoute(
        path: '/recent-browsing',
        name: 'recent-browsing',
        builder: (context, state) => const RecentBrowsingPage(),
      ),
      GoRoute(
        path: '/hotel-reviews/:hotelId',
        name: 'hotel-reviews',
        builder: (context, state) {
          final hotelId = int.tryParse(state.pathParameters['hotelId'] ?? '0') ?? 0;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return HotelReviewsPage(
            hotelId: hotelId,
            hotelName: extra['hotelName'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/checkout/:id',
        name: 'checkout',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          final bookingId = extra?['bookingId'] as int? ?? id;
          return CheckoutPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/coupons',
        name: 'coupons',
        builder: (context, state) => const CouponCenterPage(),
      ),
      GoRoute(
        path: '/extend-stay/:id',
        name: 'extend-stay',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          final extra = state.extra as Map<String, dynamic>?;
          final bookingId = extra?['bookingId'] as int? ?? id;
          return ExtendStayPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/frequent-guests',
        name: 'frequent-guests',
        builder: (context, state) => const FrequentGuestPage(),
      ),
      GoRoute(
        path: '/personal-info',
        name: 'personal-info',
        builder: (context, state) => const PersonalInfoPage(),
      ),
      GoRoute(
        path: '/wallet', 
        name: 'wallet', 
        builder: (context, state) => const WalletPage()
      ),
      GoRoute(
        path: '/member',
        name: 'member',
        builder: (context, state) => const MemberPage(),
      ),
      GoRoute(
        path: '/room-service',
        name: 'room-service',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RoomServicePage(bookingId: extra?['bookingId'] as int?, initialTab: extra?['initialTab'] as int?);
        },
      ),
      GoRoute(
        path: '/ai-butler',
        name: 'ai-butler',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AiButlerPage(bookingId: extra?['bookingId'] as int?, roomId: extra?['roomId'] as int?);
        },
      ),
      // Admin routes
      GoRoute(path: '/admin/environment', builder: (context, state) => const EnvironmentMonitorPage()),
      GoRoute(path: '/admin/room-types', builder: (context, state) => const RoomTypeManagePage()),
      GoRoute(path: '/admin/floors', builder: (context, state) => const FloorManagePage()),
      GoRoute(path: '/admin/price-calendar', builder: (context, state) => const PriceCalendarPage()),
      GoRoute(path: '/admin/coupons', builder: (context, state) => const CouponManagePage()),
      GoRoute(path: '/admin/users', builder: (context, state) => const UserManagePage()),
      // Reception routes
      GoRoute(path: '/reception/checkin-out', builder: (context, state) => const CheckInOutPage()),
      GoRoute(path: '/reception/bookings', builder: (context, state) => const BookingsPage()),
      GoRoute(path: '/reception/devices', builder: (context, state) => const DeviceManagementPage()),
      GoRoute(path: '/reception/work-orders', builder: (context, state) => const WorkOrdersPage()),
      GoRoute(path: '/reception/delivery', builder: (context, state) => const DeliveryOrdersPage()),
      GoRoute(path: '/reception/room-availability', builder: (context, state) => const RoomAvailabilityPage()),
      GoRoute(path: '/reception/voice-calls', builder: (context, state) => const VoiceCallsPage()),
      GoRoute(path: '/reception/bills', builder: (context, state) => const BillsPage()),
      GoRoute(path: '/reception/price-settings', builder: (context, state) => const PriceSettingsPage()),
      GoRoute(path: '/reception/environment', builder: (context, state) => const ReceptionEnvironmentPage()),
      GoRoute(path: '/reception/price-calendar', builder: (context, state) => const PriceCalendarPage()),
      GoRoute(path: '/reception/coupons', builder: (context, state) => const CouponManagePage()),
      // System routes
      GoRoute(path: '/system/settings', builder: (context, state) => const SystemSettingsPage()),
      GoRoute(path: '/system/mqtt', builder: (context, state) => const MqttManagePage()),
      GoRoute(path: '/system/pending-devices', builder: (context, state) => const PendingDevicesPage()),
      GoRoute(path: '/admin/knowledge-base', builder: (context, state) => const KnowledgeBaseManagePage()),
    ],
  );
});
