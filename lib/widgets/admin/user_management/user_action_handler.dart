import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../services/auth/user_id_service.dart';

/// Handles user actions such as viewing details and deactivating/reactivating accounts
class UserActionHandler {
  static Future<void> handleAction({
    required BuildContext context,
    required String action,
    required Map<String, dynamic> user,
    required Future<void> Function() onRefresh,
  }) async {
    final fName = user['first_name'] ?? '';
    final sName = user['surname'] ?? '';
    final fullName = '$fName $sName'.trim();
    final phone = user['phone']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final rawUserStatus =
        (user['status'] ?? 'unverified').toString().toLowerCase();
    final isUserDeactivated =
        rawUserStatus == 'deactivated' || rawUserStatus == 'de_activated';
    final isUserUnverified =
        rawUserStatus == 'unverified' || rawUserStatus == 'pending';
    final isUserVerified = !isUserDeactivated && !isUserUnverified;

    if (action == 'view') {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Banner
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.08),
                          AppColors.primary.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFF3F4F6)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            (fullName.isNotEmpty
                                    ? fullName[0]
                                    : (email.isNotEmpty ? email[0] : 'U'))
                                .toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName.isNotEmpty
                                    ? fullName
                                    : 'Registered User',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Role Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      (user['role'] ?? 'user')
                                          .toString()
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Status Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isUserDeactivated
                                          ? const Color(0xFFFEE2E2)
                                          : (isUserUnverified
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFDCFCE7)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isUserDeactivated
                                          ? 'DEACTIVATED'
                                          : (isUserUnverified
                                              ? 'UNVERIFIED'
                                              : 'ACTIVE'),
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        color: isUserDeactivated
                                            ? const Color(0xFFDC2626)
                                            : (isUserUnverified
                                                ? const Color(0xFFD97706)
                                                : const Color(0xFF16A34A)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Detail Items
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email.isNotEmpty ? email : 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone.isNotEmpty ? phone : 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Barangay',
                          value: user['barangay']?.toString().isNotEmpty == true
                              ? user['barangay'].toString()
                              : 'N/A',
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          icon: Icons.verified_user_outlined,
                          label: 'Email Verification',
                          value: isUserVerified
                              ? 'Verified'
                              : 'Pending Verification',
                          valueColor: isUserVerified
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                      ],
                    ),
                  ),

                  // Footer Actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            foregroundColor: const Color(0xFF374151),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (action == 'contact') {
      AppToast.show(
        context,
        phone.isNotEmpty
            ? 'Contacting $phone...'
            : 'No phone number for $fullName',
        icon: Icons.phone_rounded,
      );
    } else if (action == 'view_id') {
      await _showViewIdDialog(context, user, onRefresh);
    } else if (action == 'delete' ||
        action == 'deactivate' ||
        action == 'toggle_status') {
      final isSelf =
          user['user_id'] == Supabase.instance.client.auth.currentUser?.id;
      if (isSelf) {
        AppToast.error(context, 'You cannot deactivate your own account.');
        return;
      }

      final rawStatus = (user['status'] ?? 'active').toString().toLowerCase();
      final isDeactivated =
          rawStatus == 'deactivated' || rawStatus == 'de_activated';
      final actionTitle =
          isDeactivated ? 'Reactivate Account' : 'Deactivate Account';
      final targetStatus = isDeactivated ? 'active' : 'deactivated';

      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Accent Strip
                  Container(
                    height: 4,
                    color: isDeactivated
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Prominent Halo Icon Badge
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: isDeactivated
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDeactivated
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFFECACA),
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            isDeactivated
                                ? Icons.check_circle_rounded
                                : Icons.block_rounded,
                            color: isDeactivated
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Title
                        Text(
                          actionTitle,
                          style: GoogleFonts.montserrat(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // User Summary Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isDeactivated
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEE2E2),
                                child: Text(
                                  (fullName.isNotEmpty
                                          ? fullName[0]
                                          : (email.isNotEmpty ? email[0] : 'U'))
                                      .toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDeactivated
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.isNotEmpty
                                          ? fullName
                                          : 'Unnamed User',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (email.isNotEmpty)
                                      Text(
                                        email,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: const Color(0xFF6B7280),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                ),
                                child: Text(
                                  (user['role'] ?? 'user')
                                      .toString()
                                      .toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Consequence Notice Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDeactivated
                                ? const Color(0xFFF0FDF4)
                                : const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDeactivated
                                  ? const Color(0xFFBBF7D0)
                                  : const Color(0xFFFFCCD3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isDeactivated
                                    ? Icons.info_outline_rounded
                                    : Icons.warning_amber_rounded,
                                size: 18,
                                color: isDeactivated
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFBE123C),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isDeactivated
                                      ? 'They will regain full system access, allowing them to sign in and interact with PetTrace.'
                                      : 'They will be immediately logged out and unable to access the system until reactivated.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: isDeactivated
                                        ? const Color(0xFF166534)
                                        : const Color(0xFF9F1239),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF4B5563),
                                  side: const BorderSide(
                                      color: Color(0xFFD1D5DB)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(ctx, true),
                                icon: Icon(
                                  isDeactivated
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.block_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  actionTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDeactivated
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      try {
        final userId = user['user_id']?.toString() ?? user['id']?.toString();
        if (userId != null && userId.isNotEmpty) {
          final res = await Supabase.instance.client
              .from('users')
              .update({'status': targetStatus})
              .eq('user_id', userId)
              .select();

          if (res.isEmpty) {
            throw Exception(
              'No user row was updated. Please check Supabase Row Level Security (RLS) policies on the users table.',
            );
          }
        }
        await onRefresh();
        if (context.mounted) {
          AppToast.success(context,
              'Account for "${fullName.isNotEmpty ? fullName : email}" is now $targetStatus.');
        }
      } catch (e) {
        if (context.mounted) {
          final errStr = e.toString();
          if (errStr.contains('42501') ||
              errStr.contains('row-level security')) {
            AppToast.error(context,
                'Permission denied: Supabase RLS requires an admin update policy on table "users".');
          } else {
            AppToast.error(context, 'Failed to update account status: $e');
          }
        }
      }
    }
  }

  static Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF111827),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VIEW ID DIALOG (Authorized Admin Only)
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _showViewIdDialog(
    BuildContext context,
    Map<String, dynamic> user,
    Future<void> Function() onRefresh,
  ) async {
    final fName = user['first_name'] ?? '';
    final sName = user['surname'] ?? '';
    final fullName = '$fName $sName'.trim();
    final phone = user['phone']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final barangay = user['barangay']?.toString() ?? 'Unspecified';
    final role = (user['role'] ?? 'user').toString().toUpperCase();

    final rawStatus = (user['status'] ?? 'unverified').toString().toLowerCase();
    final isDeactivated =
        rawStatus == 'deactivated' || rawStatus == 'de_activated';
    final isUnverified = rawStatus == 'unverified' || rawStatus == 'pending';
    final isVerified = !isDeactivated && !isUnverified;

    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<Map<String, dynamic>>(
              future: UserIdService.getIdData(user),
              builder: (context, snapshot) {
                final idData = snapshot.data ?? {};
                final frontUrl = idData['id_front_url'] as String?;
                final backUrl = idData['id_back_url'] as String?;
                final uploadedAtRaw = idData['id_uploaded_at'] as String?;
                final hasIds = idData['has_ids'] == true;

                String formattedDate = 'Not recorded';
                if (uploadedAtRaw != null && uploadedAtRaw.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(uploadedAtRaw).toLocal();
                    const months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ];
                    final h = dt.hour == 0
                        ? 12
                        : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
                    final m = dt.minute.toString().padLeft(2, '0');
                    final ampm = dt.hour < 12 ? 'AM' : 'PM';
                    formattedDate =
                        '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $h:$m $ampm';
                  } catch (_) {
                    formattedDate = uploadedAtRaw;
                  }
                }

                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Strip
                      Container(
                        height: 5,
                        color: AppColors.primary,
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 20, 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primaryContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Valid ID Verification',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Submitted government identification documents',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: Color(0xFF94A3B8)),
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),

                      // Account Summary Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        AppColors.primary.withOpacity(0.15),
                                    child: Text(
                                      (fullName.isNotEmpty
                                              ? fullName[0]
                                              : (email.isNotEmpty
                                                  ? email[0]
                                                  : 'U'))
                                          .toUpperCase(),
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName.isNotEmpty
                                              ? fullName
                                              : 'Registered User',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF111827),
                                          ),
                                        ),
                                        Text(
                                          email.isNotEmpty ? email : phone,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Verification Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDeactivated
                                          ? const Color(0xFFEF4444)
                                              .withOpacity(0.12)
                                          : (isVerified
                                              ? const Color(0xFF22C55E)
                                                  .withOpacity(0.12)
                                              : const Color(0xFFF59E0B)
                                                  .withOpacity(0.12)),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isDeactivated
                                          ? 'DEACTIVATED'
                                          : (isVerified
                                              ? 'VERIFIED'
                                              : 'UNVERIFIED'),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDeactivated
                                            ? const Color(0xFFDC2626)
                                            : (isVerified
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFD97706)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(
                                  height: 1, color: Color(0xFFE2E8F0)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  _idMetaItem(Icons.location_on_outlined,
                                      'Barangay', 'Brgy. $barangay'),
                                  _idMetaItem(Icons.phone_outlined, 'Phone',
                                      phone.isNotEmpty ? phone : '-'),
                                  _idMetaItem(Icons.calendar_today_outlined,
                                      'Upload Date', formattedDate),
                                  _idMetaItem(
                                      Icons.shield_outlined, 'Role', role),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ID Images Preview
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submitted Identification Cards',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (snapshot.connectionState ==
                                ConnectionState.waiting)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary),
                                ),
                              )
                            else if (!hasIds)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.no_accounts_outlined,
                                        size: 46, color: Colors.grey.shade400),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No ID photos on file',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'This user registered before the valid ID upload requirement.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 500;
                                  final frontCard = _buildAdminIdCard(
                                    context: context,
                                    label: 'ID Front',
                                    url: frontUrl,
                                  );
                                  final backCard = _buildAdminIdCard(
                                    context: context,
                                    label: 'ID Back',
                                    url: backUrl,
                                  );

                                  if (isWide) {
                                    return Row(
                                      children: [
                                        Expanded(child: frontCard),
                                        const SizedBox(width: 14),
                                        Expanded(child: backCard),
                                      ],
                                    );
                                  }
                                  return Column(
                                    children: [
                                      frontCard,
                                      const SizedBox(height: 14),
                                      backCard,
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),

                      // Footer Actions
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(color: Color(0xFFF1F5F9)),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (isUnverified) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final uid = user['user_id']?.toString() ?? '';
                                  if (uid.isNotEmpty) {
                                    try {
                                      await Supabase.instance.client
                                          .from('users')
                                          .update({'status': 'active'}).eq(
                                              'user_id', uid);
                                      if (context.mounted) {
                                        AppToast.show(
                                          context,
                                          '$fullName is now marked as Verified.',
                                          icon: Icons.check_circle_rounded,
                                        );
                                      }
                                      if (ctx.mounted) {
                                        Navigator.pop(ctx);
                                      }
                                      await onRefresh();
                                    } catch (e) {
                                      if (context.mounted) {
                                        AppToast.error(context,
                                            'Error verifying user: $e');
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(Icons.verified_user_rounded,
                                    size: 16),
                                label: Text(
                                  'Mark as Verified',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _idMetaItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  static Widget _buildAdminIdCard({
    required BuildContext context,
    required String label,
    required String? url,
  }) {
    final hasUrl = url != null && url.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.credit_card_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                if (hasUrl)
                  InkWell(
                    onTap: () => _showZoomableImageDialog(context, label, url),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fullscreen_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            'Zoom',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Image Preview Container
          InkWell(
            onTap: hasUrl
                ? () => _showZoomableImageDialog(context, label, url)
                : null,
            child: SizedBox(
              height: 180,
              child: !hasUrl
                  ? Center(
                      child: Text(
                        'Not provided',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    )
                  : url.startsWith('data:image')
                      ? Image.memory(
                          base64Decode(url.split(',').last),
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.broken_image_rounded,
                                    size: 32, color: Color(0xFFCBD5E1)),
                                const SizedBox(height: 6),
                                Text(
                                  'Image unavailable',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  static void _showZoomableImageDialog(
    BuildContext context,
    String title,
    String url,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: url.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(url.split(',').last),
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
