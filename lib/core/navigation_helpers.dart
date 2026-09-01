import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'app_routes.dart';

Future<void> handleSafeBack(BuildContext context, {String? fallbackRoute}) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    String route = fallbackRoute ?? AppRoutes.home;
    if (fallbackRoute == null) {
      try {
        final role = await AuthService.instance.getCurrentUserRole();
        if (role == UserRole.superAdmin) {
          route = AppRoutes.superAdminHome;
        } else if (role == UserRole.admin) {
          route = AppRoutes.barangayAdminHome;
        }
      } catch (_) {
        // Fallback to general home if error resolving role
      }
    }
    navigator.pushNamedAndRemoveUntil(route, (route) => false);
  }
}