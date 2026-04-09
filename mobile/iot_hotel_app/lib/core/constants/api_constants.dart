class ApiConstants {
  static String _baseUrlOverride = '';

  static void setBaseUrl(String url) {
    _baseUrlOverride = url;
  }

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }
    // 使用云服务器地址，方便所有平台测试
    return 'http://8.134.166.69:9000/api/v1/';
  }

  static const int connectTimeout = 15000;
  static const int receiveTimeout = 30000;

  static const String authLogin = 'auth/login';
  static const String authLogout = 'auth/logout';
  static const String authRegister = 'auth/register';
  static const String authMe = 'auth/me';

  static const String hotels = 'hotels/';
  static const String hotel = 'hotel/';
  static const String rooms = 'rooms/';
  static const String roomTypes = 'room-types/';
  static const String floors = 'floors/';
  static const String bookings = 'bookings/';
  static const String payments = 'payments/';
  static const String members = 'members/';
  static const String coupons = 'coupons/';
  static const String delivery = 'delivery/';
  static const String maintenance = 'maintenance/';
  static const String reviews = 'reviews/';
  static const String calls = 'calls/';
  static const String guests = 'guests/';
  static const String frequentGuests = 'frequent-guests/';
  static const String devices = 'devices/';
  static const String users = 'users/';
  static const String messages = 'messages/';
  static const String health = 'health';
  static const String upload = 'upload/';
}
