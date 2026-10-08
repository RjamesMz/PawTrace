import 'package:flutter/material.dart';
import 'admin_dashboard_analytics_view.dart';

class AdminDesktopView extends StatelessWidget {
  final String adminBarangay;
  final int registeredPets;
  final int lostReports;
  final int registeredUsers;
  final bool isLoading;
  final List<Map<String, dynamic>> pendingReports;
  final List<Map<String, dynamic>> recentActivity;

  const AdminDesktopView({
    super.key,
    required this.adminBarangay,
    required this.registeredPets,
    required this.lostReports,
    required this.registeredUsers,
    required this.isLoading,
    required this.pendingReports,
    required this.recentActivity,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDashboardAnalyticsView(
      adminBarangay: adminBarangay,
      pendingReports: pendingReports,
      recentActivity: recentActivity,
    );
  }
}

// Alias for compatibility
typedef BarangayAdminDesktopView = AdminDesktopView;
