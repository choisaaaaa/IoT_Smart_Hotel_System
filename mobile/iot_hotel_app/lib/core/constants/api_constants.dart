class ApiConstants {
  static String _baseUrlOverride = '';

  static void setBaseUrl(String url) {
    _baseUrlOverride = url;
  }

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }
    
    // 灵活配置方案
    // 方案1: 优先使用环境变量
    const String envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    
    // 方案2: 开发环境默认值
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return 'http://8.134.166.69:9000/api/v1/';
    }
    
    // 方案3: 生产环境默认值（打包到手机端使用）
    return 'http://8.134.166.69:9000/api/v1/';
  }

  static String get serverHost {
    final url = _baseUrlOverride.isNotEmpty ? _baseUrlOverride : baseUrl;
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  static const int connectTimeout = 15000;
  static const int receiveTimeout = 30000;

  static const String authLogin = 'auth/login';
  static const String authLogout = 'auth/logout';
  static const String authRegister = 'auth/register';
  static const String authMe = 'auth/me';
  static const String authResetPassword = 'auth/reset-password';
  static const String authRoleApplication = 'auth/role-application';
  static const String authRoleApplications = 'auth/role-applications';
  static const String authQrGenerate = 'auth/qr-generate';
  static const String authQrConfirm = 'auth/qr-confirm';
  static const String authQrStatus = 'auth/qr-status';

  static const String hotels = 'hotels';
  static const String hotel = 'hotel';
  static const String rooms = 'rooms';
  static const String roomTypes = 'room-types';
  static const String floors = 'floors';
  static const String bookings = 'bookings';
  static const String payments = 'payments';
  static const String members = 'members';
  static const String coupons = 'coupons';
  static const String delivery = 'delivery';
  static const String maintenance = 'maintenance';
  static const String reviews = 'reviews';
  static const String calls = 'calls';
  static const String guests = 'guests';
  static const String frequentGuests = 'frequent-guests';
  static const String devices = 'devices';
  static const String users = 'users';
  static const String messages = 'messages';
  static const String health = 'health';
  static const String upload = 'upload';
  static const String environment = 'environment';
  static const String priceCalendar = 'price-calendar';
  static const String aiButler = 'ai-butler';
  static const String systemConfig = 'system-config';
  static const String knowledgeBase = 'knowledge-base';
  static const String ratePlans = 'rate-plans';
  static const String rfid = 'rfid';
  static const String mqtt = 'mqtt';
  static const String deviceAlarms = 'device-alarms';
  static const String energy = 'energy';
  static const String favorites = 'favorites';
}
