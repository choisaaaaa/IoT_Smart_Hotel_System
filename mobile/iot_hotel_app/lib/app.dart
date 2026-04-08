import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'core/network/dio_client.dart';

class IoTHotelApp extends ConsumerStatefulWidget {
  const IoTHotelApp({super.key});

  @override
  ConsumerState<IoTHotelApp> createState() => _IoTHotelAppState();
}

class _IoTHotelAppState extends ConsumerState<IoTHotelApp> {
  @override
  void initState() {
    super.initState();
    DioClient().init();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '智联酒店',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
