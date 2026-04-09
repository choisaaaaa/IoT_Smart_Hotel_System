import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化日期格式化，支持中文
  await initializeDateFormatting('zh_CN', null);
  runApp(const ProviderScope(child: IoTHotelApp()));
}
