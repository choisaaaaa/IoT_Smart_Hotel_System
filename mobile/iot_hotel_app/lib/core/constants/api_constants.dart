class ApiConstants {
  static const String baseUrl = 'http://localhost:9000/api/v1';

  static const int connectTimeout = 15000;
  static const int receiveTimeout = 30000;

  static const String authLogin = '/auth/login';
  static const String authLogout = '/auth/logout';
  static const String authRefresh = '/auth/refresh';
  static const String authRegister = '/auth/register';

  static const String hotels = '/hotels';
  static const String rooms = '/rooms';
  static const String bookings = '/bookings';
  static const String payments = '/payments';
  static const String members = '/members';
  static const String coupons = '/coupons';
  static const String delivery = '/delivery';
  static const String maintenance = '/maintenance';
  static const String reviews = '/reviews';
  static const String calls = '/calls';
  static const String guests = '/guests';
  static const String devices = '/devices';
  static const String users = '/users';
  static const String health = '/health';
}
