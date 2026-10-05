import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../screens/admin/pets/admin_pet_detail_screen.dart';

/// DataTableSource for AdminPetsScreen on desktop web.
class PetsDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> pets;
  final BuildContext context;
  final Function(Map<String, dynamic> pet) onContact;
  final Function(Map<String, dynamic> pet) onViewMap;
  final Function(Map<String, dynamic> pet) onRepost;
  final Function(Map<String, dynamic> pet)? onViewLogs;

  PetsDataTableSource(
    this.pets,
    this.context, {
    required this.onContact,
    required this.onViewMap,
    required this.onRepost,
    this.onViewLogs,
  });

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return '-';
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
  DataRow? getRow(int index) {
    if (index >= pets.length) return null;
    final p = pets[index];

    final petName = p['name']?.toString() ?? 'Unnamed';
    final species = p['species']?.toString() ?? '';
    final breed = p['breed']?.toString() ?? '';
    final photoUrl = p['photo_url']?.toString() ?? '';
    final barangay = p['barangay']?.toString() ?? '';
    final status = (p['status']?.toString() ?? 'active').toLowerCase();

    final u = p['users'];
    final ownerName = u != null
        ? [u['first_name'], u['surname']]
            .where((s) => s != null && s.toString().isNotEmpty)
            .join(' ')
        : 'Unknown Owner';

    final isEven = index % 2 == 0;

    return DataRow.byIndex(
      index: index,
      color: WidgetStateProperty.resolveWith<Color?>(
        (states) => isEven ? Colors.white : const Color(0xFFF9FAFB),
      ),
      cells: [
        // Photo: Image.network pet photo 40x40 rounded
        DataCell(
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: photoUrl.isNotEmpty
                ? Image.network(
                    photoUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  )
                : _photoPlaceholder(),
          ),
        ),
        // Pet Name bold
        DataCell(
          Text(
            petName,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.onSurface,
            ),
          ),
        ),
        // Breed gray
        DataCell(
          Text(
            breed.isNotEmpty ? breed : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Species gray
        DataCell(
          Text(
            species.isNotEmpty ? species : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Owner name orange
        DataCell(
          Text(
            ownerName.isNotEmpty ? ownerName : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
        // Barangay gray
        DataCell(
          Text(
            barangay.isNotEmpty ? barangay : '-',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Colored status chip
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'active'
                  ? const Color(0xFF22C55E).withOpacity(0.15)
                  : (status == 'archived'
                      ? const Color(0xFF64748B).withOpacity(0.15)
                      : AppColors.error.withOpacity(0.15)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: status == 'active'
                    ? const Color(0xFF22C55E)
                    : (status == 'archived'
                        ? const Color(0xFF64748B)
                        : AppColors.error),
              ),
            ),
          ),
        ),
        // Registration Date
        DataCell(
          Text(
            _formatDate(p['created_at']),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Last Modified Date
        DataCell(
          Builder(builder: (_) {
            final updated = p['updated_at'] ?? p['modified_at'];
            final hasUpdate = updated != null &&
                updated.toString().trim().isNotEmpty &&
                updated.toString() != p['created_at'].toString();
            return Text(
              hasUpdate ? _formatDate(updated) : 'None yet',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: hasUpdate ? FontWeight.w600 : FontWeight.normal,
                color: hasUpdate
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant.withOpacity(0.6),
              ),
            );
          }),
        ),
        // Action row of pet: View + Contact + View Map + Audit Log (all pill type)
        DataCell(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminPetDetailScreen(pet: p),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    'View',
                    style: GoogleFonts.inter(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () => onContact(p),
                  icon: const Icon(Icons.call, size: 13),
                  label: Text('Contact',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  onPressed: () => onViewMap(p),
                  icon: const Icon(Icons.map_outlined, size: 13),
                  label: Text('View Map',
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  onPressed: () {
                    if (onViewLogs != null) {
                      onViewLogs!(p);
                    } else {
                      showPetAuditLogDialog(context, p);
                    }
                  },
                  icon: const Icon(Icons.history_rounded, size: 13),
                  label: Text(
                    'Audit Log',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(
                        color: const Color(0xFF6366F1).withOpacity(0.6)),
                    foregroundColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.pets, color: AppColors.primary, size: 20),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => pets.length;

  @override
  int get selectedRowCount => 0;
}
