class AppConstants {
  static const String appName = '智联酒店';
  static const String appVersion = '1.0.0';

  static const String tokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userInfoKey = 'user_info';

  static const List<String> userRoles = ['admin', 'reception', 'guest'];

  static Map<String, String> roleNames = {
    'admin': '管理员',
    'reception': '前台',
    'guest': '住客',
  };

  static Map<String, String> roomStatusMap = {
    'available': '空闲',
    'occupied': '已入住',
    'cleaning': '清洁中',
    'maintenance': '维修中',
    'reserved': '已预订',
  };

  static Map<String, String> bookingStatusMap = {
    'pending': '待确认',
    'confirmed': '已确认',
    'checked_in': '已入住',
    'checked_out': '已退房',
    'cancelled': '已取消',
  };
}
