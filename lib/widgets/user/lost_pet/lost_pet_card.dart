import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../screens/user/lost_pet/lost_pet_detail_screen.dart';
import 'contact_owner_sheet.dart';
import '../../../screens/user/lost_pet/lost_pet_map_screen.dart';

/// Card widget representing a lost pet report in LostPetScreen feed.
class LostPetCard extends StatelessWidget {
  final Map<String, dynamic> pet;

  const LostPetCard({super.key, required this.pet});

  static String formatTimeAgo(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final petData = pet['pets'] as Map<String, dynamic>?;
    // 'owner_id' is the FK-hint alias used in the select query
    final userData = (pet['owner_id'] is Map<String, dynamic>
            ? pet['owner_id'] as Map<String, dynamic>
            : null) ??
        (pet['users'] as Map<String, dynamic>?);

    final petName = petData?['name'] as String? ?? 'Unknown';
    final breed = petData?['breed'] as String? ?? 'Unknown Breed';
    final imageUrl =
        pet['photo_url'] as String? ?? petData?['photo_url'] as String? ?? '';
    final rawAddress = pet['last_seen_address'] as String? ??
        pet['barangay'] as String? ??
        'Calatagan';
    final location = rawAddress
        .replaceAll(RegExp(r'\s*\(?Lat:\s*[-\d.]+,\s*Lng:\s*[-\d.]+\)?'), '')
        .trim();
    final note = pet['description'] as String? ?? '';
    final timeAgo = formatTimeAgo(pet['reported_at']);
    final status = (pet['status'] ?? 'active').toString().toLowerCase();
    final isArchived = status == 'archived' || status == 'resolved';

    final ownerName = userData != null
        ? [
            userData['first_name'],
            userData['middle_name'],
            userData['surname'],
            userData['suffix']
          ].where((s) => s != null && s.toString().isNotEmpty).join(' ')
        : 'Unknown Owner';
    final ownerPhone = (userData?['phone'] as String? ?? '').trim();
    final ownerEmail = (userData?['email'] as String? ?? '').trim();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LostPetDetailScreen(report: pet),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              color: const Color(0xFF1E1E1E),
              child: imageUrl.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child:
                              Container(color: Colors.black.withOpacity(0.3)),
                        ),
                        Center(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceContainerHigh,
                              child: const Center(
                                child: Icon(
                                  Icons.pets,
                                  size: 72,
                                  color: AppColors.primaryContainer,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: AppColors.surfaceContainerHigh,
                      child: const Center(
                        child: Icon(
                          Icons.pets,
                          size: 72,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              petName,
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              breed,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isArchived
                              ? const Color(0xFF64748B).withOpacity(0.15)
                              : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          isArchived ? 'ARCHIVED' : 'LOST',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isArchived
                                ? const Color(0xFF475569)
                                : AppColors.error,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Owner: $ownerName',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      note,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ContactOwnerSheet.show(
                            context,
                            ownerName: ownerName,
                            phone: ownerPhone,
                            email: ownerEmail,
                          ),
                          icon: const Icon(Icons.call, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Contact owner'),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            side: BorderSide(
                              color: AppColors.outlineVariant.withOpacity(0.28),
                            ),
                            foregroundColor: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            double? lat =
                                (pet['last_seen_lat'] as num?)?.toDouble();
                            double? lng =
                                (pet['last_seen_lon'] as num?)?.toDouble();
                            if (lat == null || lng == null) {
                              final regExp = RegExp(
                                  r'Lat:\s*([-\d.]+),\s*Lng:\s*([-\d.]+)');
                              final match = regExp.firstMatch(rawAddress);
                              if (match != null) {
                                lat = double.tryParse(match.group(1)!);
                                lng = double.tryParse(match.group(2)!);
                              }
                            }
                            if (lat != null && lng != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LostPetMapScreen(
                                    petName: petName,
                                    lat: lat!,
                                    lon: lng!,
                                    address: location,
                                  ),
                                ),
                              );
                              return;
                            }
                            AppToast.info(
                              context,
                              'No GPS coordinates available for this location.',
                            );
                          },
                          icon: const Icon(Icons.map_outlined, size: 16),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('View map'),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 8,
                            ),
                            minimumSize: const Size.fromHeight(46),
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
    );
  }
}
