import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../admin/web/admin_web_layout.dart';
import '../admin/dashboard/admin_dashboard_analytics_view.dart';
import 'super_admin_data_tables.dart';

/// SuperAdmin desktop web view implementation.
class SuperAdminDesktopView extends StatelessWidget {
  final bool isLoading;
  final int totalPets;
  final int totalUsers;
  final int totalLostReports;
  final int totalAdmins;
  final List<Map<String, dynamic>> recentReports;
  final List<Map<String, dynamic>> admins;
  final List<Map<String, dynamic>>? recentActivity;
  final int webTabIndex;
  final ValueChanged<int> onTabChanged;
  final Function(String userId, String email, bool isDeactivated)
      onToggleAdminStatus;
  final VoidCallback onAddAdmin;

  const SuperAdminDesktopView({
    super.key,
    required this.isLoading,
    required this.totalPets,
    required this.totalUsers,
    required this.totalLostReports,
    required this.totalAdmins,
    required this.recentReports,
    required this.admins,
    this.recentActivity,
    required this.webTabIndex,
    required this.onTabChanged,
    required this.onToggleAdminStatus,
    required this.onAddAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final isAdminTab = webTabIndex == 4 || webTabIndex == 5;
    if (isLoading) {
      return AdminWebLayout(
        currentIndex: isAdminTab ? 5 : 0,
        pageTitle: isAdminTab ? 'Barangay Admins' : 'Super Admin Dashboard',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(60.0),
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      );
    }

    if (isAdminTab) {
      return AdminWebLayout(
        currentIndex: 5,
        pageTitle: 'Barangay Admins',
        body: _buildWebAdminsSection(context),
      );
    }

    return AdminWebLayout(
      currentIndex: 0,
      pageTitle: 'Super Admin Dashboard',
      body: _buildWebDashboard(context),
    );
  }

  Widget _buildWebDashboard(BuildContext context) {
    return AdminDashboardAnalyticsView(
      adminBarangay: '',
      isSuperAdmin: true,
      pendingReports: recentReports,
      recentActivity: recentActivity,
    );
  }

  Widget _buildWebAdminsSection(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          cardColor: Colors.white,
          dividerColor: Colors.grey.shade200,
        ),
        child: PaginatedDataTable(
          header: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Dashboard',
                onPressed: () => onTabChanged(0),
              ),
              const SizedBox(width: 8),
              Text(
                'Barangay Administrators',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onAddAdmin,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Add Admin',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          rowsPerPage: 10,
          showFirstLastButtons: true,
          columns: const [
            DataColumn(label: Text('Avatar')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Assigned Barangay')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          source: AdminsDataTableSource(
            admins,
            onToggleStatus: onToggleAdminStatus,
          ),
        ),
      ),
    );
  }
}
