import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';

/// Modern status badge with glow effect and vibrant palette
class AdminPetStatusBadge extends StatelessWidget {
  final String rawStatus;

  const AdminPetStatusBadge({super.key, required this.rawStatus});

  @override
  Widget build(BuildContext context) {
    final status = rawStatus.toLowerCase().trim();
    Color bg;
    Color fg;
    Color dotColor;
    String label;
    IconData icon;

    switch (status) {
      case 'archived':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        dotColor = const Color(0xFF64748B);
        label = 'ARCHIVED';
        icon = Icons.archive_outlined;
        break;
      case 'lost':
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFDC2626);
        dotColor = const Color(0xFFEF4444);
        label = 'LOST PET';
        icon = Icons.warning_amber_rounded;
        break;
      case 'found':
        bg = const Color(0xFFF0FDF4);
        fg = const Color(0xFF15803D);
        dotColor = const Color(0xFF22C55E);
        label = 'FOUND';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'active':
      default:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        dotColor = const Color(0xFF10B981);
        label = status.isNotEmpty ? status.toUpperCase() : 'ACTIVE';
        icon = Icons.pets_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: dotColor.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4-metric cards with micro-icons and clean elevated tiles
class AdminPetInfoGridCard extends StatelessWidget {
  final String dobDisplay;
  final String weight;
  final String color;
  final String collarId;

  const AdminPetInfoGridCard({
    super.key,
    required this.dobDisplay,
    required this.weight,
    required this.color,
    required this.collarId,
  });

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCollar = collarId.isNotEmpty &&
        collarId.toUpperCase() != 'N/A' &&
        collarId.toUpperCase() != 'NONE' &&
        collarId != '-';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTile(
                icon: Icons.calendar_today_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                label: 'Birth Date',
                value: dobDisplay,
                subtitle: dobDisplay != '-' ? 'Registered DOB' : 'Not specified',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTile(
                icon: Icons.monitor_weight_outlined,
                iconColor: const Color(0xFF0D9488),
                iconBg: const Color(0xFFF0FDFA),
                label: 'Weight',
                value: weight != '-' ? '$weight kg' : 'Unknown',
                subtitle: 'Body mass',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTile(
                icon: Icons.palette_outlined,
                iconColor: const Color(0xFFD97706),
                iconBg: const Color(0xFFFFFBEB),
                label: 'Color / Markings',
                value: color.isNotEmpty ? color : 'Standard',
                subtitle: 'Coat pattern',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTile(
                icon: hasCollar
                    ? Icons.sensors_rounded
                    : Icons.sensors_off_rounded,
                iconColor: hasCollar
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF94A3B8),
                iconBg: hasCollar
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
                label: 'Collar ID',
                value: hasCollar ? collarId : 'No collar',
                subtitle: hasCollar ? 'Paired tracking tag' : 'Unpaired',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Owner information card with avatar, verified contact badges, and quick call button
class AdminPetOwnerCard extends StatelessWidget {
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String? barangay;

  const AdminPetOwnerCard({
    super.key,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    this.barangay,
  });

  Future<void> _makeCall(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      AppToast.error(context, 'No phone number available.');
      return;
    }
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        AppToast.error(context, 'Could not launch phone dialer.');
      }
    }
  }

  Future<void> _sendEmail(BuildContext context, String email) async {
    if (email.isEmpty || email == '-') {
      AppToast.error(context, 'No email address on record.');
      return;
    }
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = ownerName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    final hasPhone = ownerPhone.isNotEmpty && ownerPhone != '-';
    final hasEmail = ownerEmail.isNotEmpty && ownerEmail != '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar with initials
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'P',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerName,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (barangay != null && barangay!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            'Brgy. $barangay, Catanduanes',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Verified Pet Owner',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Contact Detail Rows
          _contactItem(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: hasPhone ? ownerPhone : 'Not provided',
            onTap: hasPhone ? () => _makeCall(context, ownerPhone) : null,
            actionLabel: hasPhone ? 'Call' : null,
          ),
          const SizedBox(height: 10),
          _contactItem(
            icon: Icons.email_outlined,
            title: 'Email',
            value: hasEmail ? ownerEmail : 'Not provided',
            onTap: hasEmail ? () => _sendEmail(context, ownerEmail) : null,
            actionLabel: hasEmail ? 'Email' : null,
          ),
        ],
      ),
    );
  }

  Widget _contactItem({
    required IconData icon,
    required String title,
    required String value,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null && actionLabel != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.primary,
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Audit history card showing registration date, last modified date, and quick Excel export button
class AdminPetAuditSummaryCard extends StatelessWidget {
  final Map<String, dynamic> pet;
  final VoidCallback onViewLogs;

  const AdminPetAuditSummaryCard({
    super.key,
    required this.pet,
    required this.onViewLogs,
  });

  String _formatDate(dynamic value) {
    if (value == null) return 'N/A';
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return 'N/A';
    try {
      final dt = DateTime.parse(str).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final regDate = _formatDate(pet['created_at']);
    final rawUpdate = pet['updated_at'] ?? pet['modified_at'];
    final hasUpdate = rawUpdate != null &&
        rawUpdate.toString().trim().isNotEmpty &&
        rawUpdate.toString() != pet['created_at'].toString();
    final modifiedDate = hasUpdate ? _formatDate(rawUpdate) : 'No edits yet';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined,
                  size: 16, color: Color(0xFF4F46E5)),
              const SizedBox(width: 6),
              Text(
                'PROFILE AUDIT & INTEGRITY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: const Color(0xFF4F46E5),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onViewLogs,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'View Details',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 10, color: Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Registered On',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      regDate,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 26, color: const Color(0xFFCBD5E1)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last Modified',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      modifiedDate,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: hasUpdate
                            ? AppColors.onSurface
                            : AppColors.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
