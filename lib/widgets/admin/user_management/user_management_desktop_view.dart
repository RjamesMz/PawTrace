import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/auth/auth_service.dart';
import 'users_data_table_source.dart';

/// Desktop view for User Management screen displaying paginated data tables for citizens and admins
class UserManagementDesktopView extends StatelessWidget {
  final UserRole currentUserRole;
  final int selectedUserTypeTab;
  final List<Map<String, dynamic>> filteredCitizens;
  final List<Map<String, dynamic>> filteredAdmins;
  final Widget roleSegmentedSwitcher;
  final Widget searchBar;
  final Widget filterPills;
  final VoidCallback onRefresh;
  final VoidCallback onShowAddAdminModal;
  final void Function(String action, Map<String, dynamic> user) onAction;

  const UserManagementDesktopView({
    super.key,
    required this.currentUserRole,
    required this.selectedUserTypeTab,
    required this.filteredCitizens,
    required this.filteredAdmins,
    required this.roleSegmentedSwitcher,
    required this.searchBar,
    required this.filterPills,
    required this.onRefresh,
    required this.onShowAddAdminModal,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin = currentUserRole == UserRole.superAdmin;
    final showAdmins = isSuperAdmin && selectedUserTypeTab == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSuperAdmin) roleSegmentedSwitcher,
        if (!showAdmins)
          // ── 1. Registered Users Section Card ──
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar and filter chips in header area
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: searchBar),
                        const SizedBox(width: 16),
                        filterPills,
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, tableConstraints) {
                      final availableWidth = tableConstraints.maxWidth - 48;
                      final dynamicSpacing =
                          ((availableWidth - 800) / 7).clamp(24.0, 220.0);
                      return Theme(
                        data: Theme.of(context).copyWith(
                          cardColor: Colors.white,
                          dividerColor: Colors.grey.shade200,
                        ),
                        child: PaginatedDataTable(
                          columnSpacing: dynamicSpacing,
                          horizontalMargin: 24,
                          header: Row(
                            children: [
                              Text(
                                'Registered Users (${filteredCitizens.length})',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh',
                                onPressed: onRefresh,
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
                            DataColumn(label: Text('Barangay')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          source: UsersDataTableSource(
                            filteredCitizens,
                            onAction: onAction,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          )
        else
          // ── 2. Barangay Administrators Section Card (Super Admin only) ──
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(child: searchBar),
                        const SizedBox(width: 16),
                        filterPills,
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, tableConstraints) {
                      final availableWidth = tableConstraints.maxWidth - 48;
                      final dynamicSpacing =
                          ((availableWidth - 800) / 7).clamp(24.0, 220.0);
                      return Theme(
                        data: Theme.of(context).copyWith(
                          cardColor: Colors.white,
                          dividerColor: Colors.grey.shade200,
                        ),
                        child: PaginatedDataTable(
                          columnSpacing: dynamicSpacing,
                          horizontalMargin: 24,
                          header: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF00796B).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.shield_rounded,
                                  color: Color(0xFF00796B),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Barangay Administrators (${filteredAdmins.length})',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: onShowAddAdminModal,
                                icon: const Icon(Icons.add, size: 16),
                                label: Text(
                                  'Add Admin',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh',
                                onPressed: onRefresh,
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
                            DataColumn(label: Text('Barangay')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Actions')),
                          ],
                          source: UsersDataTableSource(
                            filteredAdmins,
                            onAction: onAction,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
