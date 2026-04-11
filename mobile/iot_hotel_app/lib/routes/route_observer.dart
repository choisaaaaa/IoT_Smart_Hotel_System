import 'package:flutter/material.dart';

/// 路由观察者，用于记录页面切换日志
class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute('Push', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRoute('Pop', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _logRoute('Replace', newRoute, oldRoute);
  }

  void _logRoute(String action, Route<dynamic>? current, Route<dynamic>? previous) {
    final currentName = current?.settings.name ?? 'unnamed';
    final previousName = previous?.settings.name ?? 'none';
    debugPrint('🚩 [Route Log] $action: from "$previousName" to "$currentName"');
  }
}
