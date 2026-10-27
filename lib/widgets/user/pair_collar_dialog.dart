import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';

/// Displays a dialog to pair or unpair a GPS collar to a pet.
/// Enforces the business rule: 1 Collar for 1 Pet only.
Future<String?> showPairCollarDialog({
  required BuildContext context,
  required Map<String, dynamic> pet,
}) async {
  final petId = pet['pet_id'];
  final petName = pet['name'] ?? 'Pet';
  final currentCollarId = pet['gps_id'] as String?;

  return showDialog<String?>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      final textCtrl = TextEditingController(text: currentCollarId ?? '');
      bool isSubmitting = false;
      String? errorMessage;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.sensors_rounded,
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
                                currentCollarId == null
                                    ? 'Pair GPS '
                                    : 'Manage GPS ',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                petName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 1 Collar = 1 Pet rule notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rule: 1 gps for 1 pet only. A gps cannot be paired with another pet while active.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Input field
                    Text(
                      'GPS Device ID / Serial',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      textCapitalization: TextCapitalization.characters,
                      autofocus: currentCollarId == null,
                      enabled: !isSubmitting,
                      decoration: InputDecoration(
                        hintText: 'e.g. COL-1001',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.onSurfaceVariant.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),

                    // Error message
                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        // Unpair button (if already paired)
                        if (currentCollarId != null) ...[
                          OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setDialogState(() {
                                      isSubmitting = true;
                                      errorMessage = null;
                                    });

                                    try {
                                      final idToClean = currentCollarId.trim();

                                      // 1. Fetch latest telemetry before unpairing so the pin is retained
                                      double? lastLat;
                                      double? lastLon;
                                      String? lastAt;

                                      try {
                                        final ping = await Supabase.instance.client
                                            .from('gps_locations')
                                            .select('lat, lon, recorded_at')
                                            .eq('gps_id', idToClean)
                                            .order('recorded_at', ascending: false)
                                            .limit(1)
                                            .maybeSingle();

                                        if (ping != null) {
                                          lastLat =
                                              (ping['lat'] as num?)?.toDouble();
                                          lastLon =
                                              (ping['lon'] as num?)?.toDouble();
                                          lastAt =
                                              ping['recorded_at']?.toString();
                                        }
                                      } catch (locErr) {
                                        debugPrint(
                                            '[CollarUnpair] Notice fetching collar location: $locErr');
                                      }

                                      lastLat ??= (pet['last_seen_lat'] as num?)
                                          ?.toDouble();
                                      lastLon ??= (pet['last_seen_lon'] as num?)
                                          ?.toDouble();
                                      lastAt ??= pet['last_seen_at']?.toString();

                                      final barangay =
                                          pet['barangay']?.toString() ??
                                              'Calatagan';
                                      final String? addressWithCoords =
                                          (lastLat != null && lastLon != null)
                                              ? '$barangay (Lat: ${lastLat.toStringAsFixed(5)}, Lng: ${lastLon.toStringAsFixed(5)})'
                                              : null;

                                      // 2. Lock the pin permanently into any active lost reports for this pet
                                      if (lastLat != null && lastLon != null) {
                                        try {
                                          await Supabase.instance.client
                                              .from('lost_reports')
                                              .update({
                                                'last_seen_lat': lastLat,
                                                'last_seen_lon': lastLon,
                                                if (addressWithCoords != null)
                                                  'last_seen_address':
                                                      addressWithCoords,
                                              })
                                              .eq('pet_id', petId)
                                              .eq('status', 'active');
                                        } catch (repErr) {
                                          debugPrint(
                                              '[CollarUnpair] Notice locking lost report pin: $repErr');
                                        }
                                      }

                                      // 3. Clear gps_id from pet row while retaining last known coordinates
                                      final petUpdate = <String, dynamic>{
                                        'gps_id': null,
                                      };
                                      if (lastLat != null && lastLon != null) {
                                        petUpdate['last_seen_lat'] = lastLat;
                                        petUpdate['last_seen_lon'] = lastLon;
                                        if (addressWithCoords != null) {
                                          petUpdate['last_seen_address'] =
                                              addressWithCoords;
                                        }
                                        if (lastAt != null) {
                                          petUpdate['last_seen_at'] = lastAt;
                                        }
                                      }

                                      try {
                                        await Supabase.instance.client
                                            .from('pets')
                                            .update(petUpdate)
                                            .eq('pet_id', petId);
                                      } catch (updateErr) {
                                        debugPrint(
                                            '[CollarUnpair] Updating pets with last_seen coords: ');
                                        // Graceful fallback if schema does not yet have last_seen columns
                                        await Supabase.instance.client
                                            .from('pets')
                                            .update({'gps_id': null})
                                            .eq('pet_id', petId);
                                      }

                                      // 4. Update local in-memory pet map so calling screens retain the pin
                                      pet['gps_id'] = null;
                                      if (lastLat != null && lastLon != null) {
                                        pet['last_seen_lat'] = lastLat;
                                        pet['last_seen_lon'] = lastLon;
                                        if (lastAt != null) {
                                          pet['last_seen_at'] = lastAt;
                                        }
                                        if (addressWithCoords != null) {
                                          pet['last_seen_address'] =
                                              addressWithCoords;
                                        }
                                      }

                                      if (context.mounted) {
                                        Navigator.pop(context, '__unpaired__');
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        errorMessage = AppErrors.format(
                                          e,
                                          fallback:
                                              'Failed to unpair collar. Please try again.',
                                        );
                                      });
                                    }
                                  },
                            icon: const Icon(Icons.link_off_rounded, size: 16),
                            label: const Text('Unpair'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: AppColors.error.withOpacity(0.5),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceVariant,
                              side: BorderSide(
                                color:
                                    AppColors.outlineVariant.withOpacity(0.7),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Pair / Save Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final enteredId = textCtrl.text.trim();
                                    if (enteredId.isEmpty) {
                                      setDialogState(() {
                                        errorMessage =
                                            'Please enter a Collar ID';
                                      });
                                      return;
                                    }

                                    // If same as current, nothing changed
                                    if (enteredId == currentCollarId) {
                                      Navigator.pop(context, currentCollarId);
                                      return;
                                    }

                                    setDialogState(() {
                                      isSubmitting = true;
                                      errorMessage = null;
                                    });

                                    try {
                                      // 1. Verify 1 collar = 1 pet rule
                                      final existingPet = await Supabase
                                          .instance.client
                                          .from('pets')
                                          .select('pet_id')
                                          .eq('gps_id', enteredId)
                                          .neq('pet_id', petId)
                                          .maybeSingle();

                                      if (existingPet != null) {
                                        setDialogState(() {
                                          isSubmitting = false;
                                          errorMessage =
                                              'Collar "$enteredId" is already paired to another pet. 1 collar can only belong to 1 pet.';
                                        });
                                        return;
                                      }

                                      // 2. Purge any stale location history for this collar so the newly paired pet starts fresh
                                      try {
                                        await Supabase.instance.client
                                            .from('gps_locations')
                                            .delete()
                                            .eq('gps_id', enteredId);
                                      } catch (locErr) {
                                        debugPrint(
                                            '[CollarPair] Notice clearing old collar locations: $locErr');
                                      }

                                      // 3. Update pet row in Supabase and reset any stale location coordinates
                                      await Supabase.instance.client
                                          .from('pets')
                                          .update({
                                        'gps_id': enteredId,
                                      }).eq('pet_id', petId);

                                      if (context.mounted) {
                                        Navigator.pop(context, enteredId);
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        final errStr = e.toString().toLowerCase();
                                        if (errStr.contains('23505') ||
                                            errStr.contains('unique') ||
                                            errStr.contains('pets_collar_id') ||
                                            errStr.contains('duplicate')) {
                                          errorMessage =
                                              'Collar "$enteredId" is already paired to another pet. 1 collar can only belong to 1 pet.';
                                        } else {
                                          errorMessage = AppErrors.format(
                                            e,
                                            fallback:
                                                'Unable to save collar. Please check your connection and try again.',
                                          );
                                        }
                                      });
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    currentCollarId == null
                                        ? 'Pair Collar'
                                        : 'Update',
                                    style: GoogleFonts.montserrat(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
