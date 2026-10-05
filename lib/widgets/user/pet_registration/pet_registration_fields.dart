import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_constants.dart';

/// Reusable uppercase form label
class PetFormLabel extends StatelessWidget {
  final String text;

  const PetFormLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

/// Form text field with PawTrace styling
class PetFormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool isNumber;

  const PetFormField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PetFormLabel(text: label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AppColors.secondaryContainer.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primaryContainer,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Species dropdown (Dog / Cat)
class PetSpeciesDropdown extends StatelessWidget {
  final String? selectedSpecies;
  final ValueChanged<String?> onChanged;

  const PetSpeciesDropdown({
    super.key,
    required this.selectedSpecies,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PetFormLabel(text: 'Species'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: selectedSpecies == 'Dog' || selectedSpecies == 'Cat'
              ? selectedSpecies
              : 'Dog',
          items: const [
            DropdownMenuItem(
              value: 'Dog',
              child: Text(' Dog'),
            ),
            DropdownMenuItem(
              value: 'Cat',
              child: Text(' Cat'),
            ),
          ],
          onChanged: onChanged,
          validator: (v) =>
              v == null ? 'PetTrace only supports Dogs and Cats' : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.secondaryContainer.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
        ),
      ],
    );
  }
}

/// Breed dropdown dynamically adapting to species (Dog / Cat), featuring
/// Aspin and Puspin at the top, and offering an 'Other' option for custom entry.
class PetBreedDropdown extends StatelessWidget {
  final String? selectedSpecies;
  final String? selectedBreed;
  final ValueChanged<String?> onBreedChanged;

  const PetBreedDropdown({
    super.key,
    required this.selectedSpecies,
    required this.selectedBreed,
    required this.onBreedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCat = (selectedSpecies ?? '').toLowerCase() == 'cat';
    final breedList = isCat ? AppConstants.catBreeds : AppConstants.dogBreeds;

    // Fallback to first breed (Puspin or Aspin) if current selection is not valid for this species
    final effectiveValue = breedList.contains(selectedBreed)
        ? selectedBreed
        : (isCat ? 'Puspin' : 'Aspin');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PetFormLabel(text: 'Breed'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: effectiveValue,
          items: breedList.map((breed) {
            String displayLabel = breed;
            if (breed == 'Aspin') {
              displayLabel = 'Aspin';
            } else if (breed == 'Puspin') {
              displayLabel = 'Puspin';
            } else if (breed == 'Other') {
              displayLabel = 'Other (Specify below)';
            }

            final isPinoy = breed == 'Aspin' || breed == 'Puspin';
            return DropdownMenuItem<String>(
              value: breed,
              child: Text(
                displayLabel,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isPinoy ? FontWeight.w600 : FontWeight.w400,
                  color: isPinoy ? AppColors.primary : AppColors.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onBreedChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.secondaryContainer.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primaryContainer,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
        ),
      ],
    );
  }
}

/// Date of birth field with date picker and N/A toggle
class PetDobField extends StatelessWidget {
  final DateTime? selectedDOB;
  final bool isDOBUnknown;
  final VoidCallback onPickDOB;
  final VoidCallback onToggleUnknown;

  const PetDobField({
    super.key,
    required this.selectedDOB,
    required this.isDOBUnknown,
    required this.onPickDOB,
    required this.onToggleUnknown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PetFormLabel(text: 'Date of Birth'),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onPickDOB,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isDOBUnknown
                        ? 'N/A'
                        : (selectedDOB != null
                            ? '${selectedDOB!.day}/${selectedDOB!.month}/${selectedDOB!.year}'
                            : 'Date / N/A'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isDOBUnknown ? FontWeight.w600 : FontWeight.w400,
                      color: (isDOBUnknown || selectedDOB != null)
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant.withOpacity(0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onToggleUnknown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color:
                          isDOBUnknown ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDOBUnknown
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'N/A',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDOBUnknown ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today,
                    size: 16, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Barangay selection dropdown
class PetBarangayDropdown extends StatelessWidget {
  final String selectedBarangay;
  final ValueChanged<String> onChanged;

  const PetBarangayDropdown({
    super.key,
    required this.selectedBarangay,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PetFormLabel(text: 'Barangay'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: selectedBarangay,
          items: AppConstants.barangays
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    m,
                    style: GoogleFonts.inter(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.secondaryContainer.withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primaryContainer,
                width: 2,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
        ),
      ],
    );
  }
}
