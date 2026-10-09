import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../admin/stat_card.dart';
import '../admin/web/admin_web_layout.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Total Pets',
                  count: totalPets,
                  icon: Icons.pets_rounded,
                  color: const Color(0xFFFF6600),
                  isLoading: isLoading,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Registered Users',
                  count: totalUsers,
                  icon: Icons.people_rounded,
                  color: const Color(0xFF4E7AC7),
                  isLoading: isLoading,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.userManagement,
                      arguments: {'tab': 0},
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Active Reports',
                  count: totalLostReports,
                  icon: Icons.flag_rounded,
                  color: const Color(0xFFBA1A1A),
                  isLoading: isLoading,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 110,
                child: StatCard(
                  label: 'Barangay Admins',
                  count: totalAdmins,
                  icon: Icons.shield_rounded,
                  color: const Color(0xFF00796B),
                  isLoading: isLoading,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.userManagement,
                      arguments: {'tab': 1},
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
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
            child: SizedBox(
              width: double.infinity,
              child: PaginatedDataTable(
                header: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Lost Pet Reports',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(
                            context, AppRoutes.adminReports);
                      },
                      child: Text(
                        'View All',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                rowsPerPage: 5,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 66,
                showFirstLastButtons: true,
                columns: const [
                  DataColumn(label: Text('Photo')),
                  DataColumn(label: Text('Pet Name')),
                  DataColumn(label: Text('Owner')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Date & Time Reported')),
                  DataColumn(label: Text('Found Date & Time')),
                  DataColumn(label: Text('Pet Status')),
                  DataColumn(label: Text('Archive')),
                ],
                source: RecentReportsDataTableSource(recentReports),
              ),
            ),
          ),
        ),
      ],
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
