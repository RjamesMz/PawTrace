import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../utils/app_errors.dart';

/// Displays a dialog to pair or unpair a GPS collar to a pet.
/// The user types the unique device code printed on their physical collar box.
/// The code is validated against the gps_devices table — it must exist
/// (pre-registered by the programmer) and must not be claimed by another pet.
Future<String?> showPairCollarDialog({
  required BuildContext context,
  required Map<String, dynamic> pet,
}) async {
  final dynamic rawPetId = pet['pet_id'] ?? pet['id'];
  final petId =
      (rawPetId is String) ? (int.tryParse(rawPetId) ?? rawPetId) : rawPetId;
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
                    // ── Header ──
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
                                    ? 'Pair GPS Collar'
                                    : 'Manage GPS Collar',
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

                    // ── Info notice ──
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
                              'Enter the unique code printed on your GPS collar box. Each code can only be paired to one pet.',
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

                    // ── Code input field ──
                    Text(
                      'GPS Device Code',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textCtrl,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'e.g. GPS-A1B2C3',
                        prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
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
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setDialogState(() => errorMessage = null);
                        }
                      },
                    ),

                    // ── Error message ──
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

                    // ── Action buttons ──
                    Row(
                      children: [
                        // Unpair button (only shown when already paired)
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

                                      // Fetch latest telemetry so the map pin is retained after unpairing
                                      double? lastLat;
                                      double? lastLon;
                                      String? lastAt;

                                      try {
                                        final ping = await Supabase
                                            .instance.client
                                            .from('gps_locations')
                                            .select('lat, lon, recorded_at')
                                            .eq('gps_id', idToClean)
                                            .order('recorded_at',
                                                ascending: false)
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
                                      lastAt ??=
                                          pet['last_seen_at']?.toString();

                                      final barangay =
                                          pet['barangay']?.toString() ??
                                              'Calatagan';
                                      final String? addressWithCoords = (lastLat !=
                                                  null &&
                                              lastLon != null)
                                          ? '$barangay (Lat: ${lastLat.toStringAsFixed(5)}, Lng: ${lastLon.toStringAsFixed(5)})'
                                          : null;

                                      // Lock pin into active lost reports
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

                                      // Clear gps_id from pet, retain last known coords
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
                                            '[CollarUnpair] Updating pets with last_seen coords: $updateErr');
                                        await Supabase.instance.client
                                            .from('pets')
                                            .update({'gps_id': null}).eq(
                                                'pet_id', petId);
                                      }

                                      // Update gps_devices status to available
                                      try {
                                        await Supabase.instance.client
                                            .from('gps_devices')
                                            .update({
                                          'status': 'available',
                                          'paired_at': null,
                                        }).eq('gps_id', idToClean);
                                      } catch (devErr) {
                                        debugPrint(
                                            '[CollarUnpair] Notice updating gps_devices status: $devErr');
                                      }

                                      // Update in-memory pet map
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

                        // Cancel button
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

                        // Pair / Save button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final enteredId =
                                        textCtrl.text.trim().toUpperCase();
                                    if (enteredId.isEmpty) {
                                      setDialogState(() {
                                        errorMessage =
                                            'Please enter the device code from your collar.';
                                      });
                                      return;
                                    }

                                    // No change
                                    if (enteredId == currentCollarId) {
                                      Navigator.pop(context, currentCollarId);
                                      return;
                                    }

                                    setDialogState(() {
                                      isSubmitting = true;
                                      errorMessage = null;
                                    });

                                    try {
                                      // 1. Verify the code exists in gps_devices (programmer-registered only)
                                      Map<String, dynamic>? deviceRow;
                                      try {
                                        deviceRow = await Supabase
                                            .instance.client
                                            .from('gps_devices')
                                            .select('gps_id')
                                            .eq('gps_id', enteredId)
                                            .maybeSingle();
                                      } catch (colErr) {
                                        // Fallback if the table was created with 'device_id' or 'id'
                                        try {
                                          deviceRow = await Supabase
                                              .instance.client
                                              .from('gps_devices')
                                              .select('device_id')
                                              .eq('device_id', enteredId)
                                              .maybeSingle();
                                        } catch (_) {
                                          deviceRow = await Supabase
                                              .instance.client
                                              .from('gps_devices')
                                              .select('id')
                                              .eq('id', enteredId)
                                              .maybeSingle();
                                        }
                                      }

                                      if (deviceRow == null) {
                                        setDialogState(() {
                                          isSubmitting = false;
                                          errorMessage =
                                              'Code "$enteredId" not found. Check the code on your collar box and try again.';
                                        });
                                        return;
                                      }

                                      // 2. Enforce 1 collar = 1 pet rule
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
                                              'This collar is already paired to another pet. Each collar can only belong to one pet.';
                                        });
                                        return;
                                      }

                                      // 3. Purge stale location history so newly-paired pet starts fresh
                                      try {
                                        await Supabase.instance.client
                                            .from('gps_locations')
                                            .delete()
                                            .eq('gps_id', enteredId);
                                      } catch (locErr) {
                                        debugPrint(
                                            '[CollarPair] Notice clearing old collar locations: $locErr');
                                      }

                                      // 4. Write new gps_id to pet row
                                      await Supabase.instance.client
                                          .from('pets')
                                          .update({'gps_id': enteredId}).eq(
                                              'pet_id', petId);
                                      pet['gps_id'] = enteredId;

                                      // 5. If previously paired to a different collar, mark old one as available
                                      if (currentCollarId != null &&
                                          currentCollarId != enteredId) {
                                        try {
                                          await Supabase.instance.client
                                              .from('gps_devices')
                                              .update({
                                            'status': 'available',
                                            'paired_at': null,
                                          }).eq('gps_id', currentCollarId);
                                        } catch (_) {
                                          try {
                                            await Supabase.instance.client
                                                .from('gps_devices')
                                                .update({
                                              'status': 'available'
                                            }).eq('gps_id', currentCollarId);
                                          } catch (_) {}
                                        }
                                      }

                                      // 6. Update gps_devices status to 'paired' and timestamp 'paired_at'
                                      try {
                                        await Supabase.instance.client
                                            .from('gps_devices')
                                            .update({
                                          'status': 'paired',
                                          'paired_at': DateTime.now()
                                              .toUtc()
                                              .toIso8601String(),
                                        }).eq('gps_id', enteredId);
                                      } catch (devErr) {
                                        // Fallback if 'paired_at' column does not exist yet
                                        try {
                                          await Supabase.instance.client
                                              .from('gps_devices')
                                              .update({'status': 'paired'}).eq(
                                                  'gps_id', enteredId);
                                        } catch (statusErr) {
                                          debugPrint(
                                              '[CollarPair] Error updating gps_devices status: $statusErr');
                                        }
                                      }

                                      if (context.mounted) {
                                        Navigator.pop(context, enteredId);
                                      }
                                    } catch (e) {
                                      setDialogState(() {
                                        isSubmitting = false;
                                        final errStr =
                                            e.toString().toLowerCase();
                                        if (errStr.contains('23505') ||
                                            errStr.contains('unique') ||
                                            errStr.contains('duplicate')) {
                                          errorMessage =
                                              'This collar is already paired to another pet.';
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
