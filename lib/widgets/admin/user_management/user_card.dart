import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';

/// User and Admin card component for list display in UserManagementScreen.
class UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isCompact;
  final VoidCallback onMenuPressed;

  const UserCard({
    super.key,
    required this.user,
    this.isCompact = false,
    required this.onMenuPressed,
  });

  static Widget avatarFallback(String name) {
    return Container(
      color: AppColors.secondaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.secondary,
          ),
        ),
      ),
    );
  }

  static Widget roleBadge(String role) {
    final isSuperAdmin = role.toLowerCase() == 'super_admin';
    final isAdmin = role.toLowerCase() == 'admin';

    Color bg = AppColors.primaryContainer.withOpacity(0.2);
    Color fg = AppColors.primary;
    String label = 'USER';

    if (isSuperAdmin) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      label = 'SUPER ADMIN';
    } else if (isAdmin) {
      bg = const Color(0xFF00796B).withOpacity(0.15);
      fg = const Color(0xFF00796B);
      label = 'ADMIN';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fName = user['first_name'] as String? ?? '';
    final mName = user['middle_name'] as String? ?? '';
    final sName = user['surname'] as String? ?? '';
    final suffix = user['suffix'] as String? ?? '';
    final name =
        [fName, mName, sName, suffix].where((s) => s.isNotEmpty).join(' ');

    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? 'user';
    final barangay = user['barangay'] as String? ?? '';
    final photoUrl = user['photo_url'] as String? ?? '';
    final phone = user['phone'] as String? ?? '';
    final rawStatus = (user['status'] ?? 'unverified').toString().toLowerCase();
    final isDeactivated =
        rawStatus == 'deactivated' || rawStatus == 'de_activated';
    final isUnverified = rawStatus == 'unverified' || rawStatus == 'pending';
    final verified = !isDeactivated && !isUnverified;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceContainer),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 40,
                height: 40,
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => avatarFallback(name),
                      )
                    : avatarFallback(name),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name.isNotEmpty ? name : 'Unnamed User',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      roleBadge(role),
                    ],
                  ),
                  if (barangay.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Brgy. $barangay',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (phone.isNotEmpty)
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withOpacity(0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDeactivated
                        ? const Color(0xFFEF4444)
                        : (verified
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFFBBF24)),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  isDeactivated
                      ? 'Deactivated'
                      : (verified ? 'Verified' : 'Unverified'),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDeactivated
                        ? const Color(0xFFDC2626)
                        : (verified
                            ? const Color(0xFF15803D)
                            : const Color(0xFFD97706)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: AppColors.outline,
                size: 20,
              ),
              onPressed: onMenuPressed,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 46,
              height: 46,
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => avatarFallback(name),
                    )
                  : avatarFallback(name),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isNotEmpty ? name : 'Unnamed User',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    roleBadge(role),
                  ],
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isDeactivated
                                ? const Color(0xFFEF4444)
                                : (verified
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFFBBF24)),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isDeactivated
                              ? 'Deactivated'
                              : (verified ? 'Verified' : 'Unverified'),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: isDeactivated
                                ? const Color(0xFFDC2626)
                                : (verified
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                    if (barangay.isNotEmpty)
                      Text(
                        '•  Brgy. $barangay',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.outline,
              size: 20,
            ),
            onPressed: onMenuPressed,
          ),
        ],
      ),
    );
  }
}
