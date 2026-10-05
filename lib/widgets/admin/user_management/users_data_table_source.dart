import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// DataTableSource for Registered Users on desktop web in UserManagementScreen.
class UsersDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> users;
  final Function(String action, Map<String, dynamic> user) onAction;

  UsersDataTableSource(this.users, {required this.onAction});

  @override
  DataRow? getRow(int index) {
    if (index >= users.length) return null;
    final user = users[index];

    final fName = user['first_name'] as String? ?? '';
    final sName = user['surname'] as String? ?? '';
    final fullName = '$fName $sName'.trim();
    final email = user['email'] as String? ?? '';
    final phone = user['phone'] as String? ?? '';
    final role = (user['role'] as String? ?? 'user').toLowerCase();
    final initial = fullName.isNotEmpty
        ? fullName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : 'U');

    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Avatar: CircleAvatar with initial
        DataCell(
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              initial,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        // Name
        DataCell(
          Text(
            fullName.isNotEmpty ? fullName : 'Unnamed User',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
        // Email
        DataCell(
          Text(
            email.isNotEmpty ? email : '-',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        // Phone
        DataCell(
          Text(
            phone.isNotEmpty ? phone : '-',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        // Barangay
        DataCell(
          Text(
            (user['barangay'] ?? '-').toString().isNotEmpty
                ? (user['barangay'] ?? '-').toString()
                : '-',
            style: GoogleFonts.inter(fontSize: 13),
          ),
        ),
        // Role badge chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: role == 'admin'
                  ? const Color(0xFF00796B).withOpacity(0.15)
                  : (role == 'super_admin'
                      ? const Color(0xFFEF4444).withOpacity(0.15)
                      : AppColors.primaryContainer.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              role == 'admin'
                  ? 'ADMIN'
                  : (role == 'super_admin'
                      ? 'SUPER ADMIN'
                      : 'USER'),
              softWrap: false,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: role == 'admin'
                    ? const Color(0xFF00796B)
                    : (role == 'super_admin'
                        ? const Color(0xFFDC2626)
                        : AppColors.primary),
              ),
            ),
          ),
        ),
        // Status chip (DEACTIVATED / VERIFIED / UNVERIFIED)
        DataCell(
          Builder(builder: (context) {
            final rawStatus =
                (user['status'] ?? 'unverified').toString().toLowerCase();
            final isDeactivated =
                rawStatus == 'deactivated' || rawStatus == 'de_activated';
            final isUnverified =
                rawStatus == 'unverified' || rawStatus == 'pending';
            final isVerified = !isDeactivated && !isUnverified;

            final String label;
            final Color bg;
            final Color fg;

            if (isDeactivated) {
              label = 'DEACTIVATED';
              bg = const Color(0xFFEF4444).withOpacity(0.15);
              fg = const Color(0xFFDC2626);
            } else if (isVerified) {
              label = 'VERIFIED';
              bg = const Color(0xFF22C55E).withOpacity(0.15);
              fg = const Color(0xFF16A34A);
            } else {
              label = 'UNVERIFIED';
              bg = const Color(0xFFF59E0B).withOpacity(0.15);
              fg = const Color(0xFFD97706);
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                softWrap: false,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            );
          }),
        ),
        // Actions: Deactivate/Reactivate button + three dot PopupMenuButton
        DataCell(
          Builder(builder: (context) {
            final rawStatus =
                (user['status'] ?? 'active').toString().toLowerCase();
            final isDeactivated =
                rawStatus == 'deactivated' || rawStatus == 'de_activated';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isDeactivated
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    size: 19,
                    color: isDeactivated
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                  tooltip: isDeactivated
                      ? 'Reactivate Account'
                      : 'Deactivate Account',
                  onPressed: () => onAction('toggle_status', user),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) => onAction(action, user),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('View Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'contact',
                      child: Row(
                        children: [
                          Icon(Icons.call_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Contact User'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(
                            isDeactivated
                                ? Icons.check_circle_outline_rounded
                                : Icons.block_rounded,
                            size: 16,
                            color: isDeactivated
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isDeactivated
                                ? 'Reactivate Account'
                                : 'Deactivate Account',
                            style: TextStyle(
                              color: isDeactivated
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => users.length;

  @override
  int get selectedRowCount => 0;
}
