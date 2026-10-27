import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../ai/pet_embedding_service.dart';
import '../audit/pet_audit_service.dart';

class PetPhotoService {
  PetPhotoService._();
  static final PetPhotoService instance = PetPhotoService._();

  final _supabase = Supabase.instance.client;

  /// True when the pet currently has an active lost report.
  /// Photos are locked while this is true so the report keeps its original photo.
  Future<bool> hasActiveLostReport(dynamic petId) async {
    final rows = await _supabase
        .from('lost_reports')
        .select('report_id')
        .eq('pet_id', petId)
        .eq('status', 'active')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  /// Prompt the user to pick an image from Camera or Gallery.
  Future<File?> pickPetImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                'Update Pet Photo',
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a clear photo of your pet for identification and AI scanning',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.camera_alt_rounded,
                                color: AppColors.primary, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Take Photo',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.outlineVariant.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.photo_library_rounded,
                                color: AppColors.primary, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'Choose Gallery',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
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

    if (source == null) return null;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return null;
    return File(picked.path);
  }

  /// Uploads a pet photo to the 'pet-photos' bucket and returns its public URL.
  Future<String> uploadPetPhoto(File file, {String prefix = 'face'}) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
    final fileExt = file.path.split('.').last;
    final fileName = 'pets/${timestamp}_${prefix}_$randomSuffix.$fileExt';

    await _supabase.storage.from('pet-photos').upload(fileName, file);
    return _supabase.storage.from('pet-photos').getPublicUrl(fileName);
  }

  /// Updates the pet's photo in Supabase 'pets' table, syncs active lost reports,
  /// and writes an audit log entry.
  Future<String> updatePetPhoto({
    required dynamic petId,
    required String petName,
    required File imageFile,
    String modifiedByRole = 'Owner',
  }) async {
    final newPhotoUrl = await uploadPetPhoto(imageFile);

    // 1. Update pets table (only columns that exist in the schema)
    await _supabase
        .from('pets')
        .update({'photo_url': newPhotoUrl})
        .eq('pet_id', petId);

    // 2. Lost reports intentionally keep the photo they were posted with.

    // 3. Log audit trail
    PetAuditService.instance.logPetModification(
      petId: petId.toString(),
      petName: petName,
      action: 'Profile Photo Updated',
      changesSummary: 'Pet photo was updated to a new picture.',
      modifiedByRole: modifiedByRole,
    );

    // 4. Evict cached network images
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    return newPhotoUrl;
  }

  /// Re-uploads the face (required) plus optional left, right and unique-mark
  /// photos, then rebuilds and saves the fused multi-angle embedding.
  /// Returns the new primary (face) photo URL.
  Future<String> updatePetPhotos({
    required dynamic petId,
    required String petName,
    required File faceImage,
    File? leftImage,
    File? rightImage,
    File? uniqueImage,
    String modifiedByRole = 'Owner',
  }) async {
    // 1. Upload every provided angle
    final newPhotoUrl = await uploadPetPhoto(faceImage, prefix: 'face');
    if (leftImage != null) await uploadPetPhoto(leftImage, prefix: 'left');
    if (rightImage != null) await uploadPetPhoto(rightImage, prefix: 'right');
    if (uniqueImage != null) await uploadPetPhoto(uniqueImage, prefix: 'unique');

    // 2. Primary photo (face)
    await _supabase
        .from('pets')
        .update({'photo_url': newPhotoUrl}).eq('pet_id', petId);

    // 3. Rebuild the fused embedding from the new angles
    try {
      final ai = PetEmbeddingService.instance;
      final faceEmb = await ai.extractEmbedding(faceImage);
      final leftEmb = leftImage != null ? await ai.extractEmbedding(leftImage) : null;
      final rightEmb = rightImage != null ? await ai.extractEmbedding(rightImage) : null;
      final uniqueEmb = uniqueImage != null ? await ai.extractEmbedding(uniqueImage) : null;

      final fused = _fuseEmbeddings([
        (faceEmb, 1.3),
        (leftEmb, 1.0),
        (rightEmb, 1.0),
        (uniqueEmb, 1.2),
      ]);
      if (fused != null) {
        await _supabase
            .from('pets')
            .update({'embedding': fused}).eq('pet_id', petId);
      }
    } catch (e) {
      debugPrint('[PetTrace] Embedding refresh failed: $e');
    }

    // 4. Lost reports intentionally keep the photo they were posted with.

    // 5. Audit trail
    final extras = [
      if (leftImage != null) 'left side',
      if (rightImage != null) 'right side',
      if (uniqueImage != null) 'unique mark',
    ];
    PetAuditService.instance.logPetModification(
      petId: petId.toString(),
      petName: petName,
      action: 'Profile Photo Updated',
      changesSummary: extras.isEmpty
          ? 'Pet photo was updated to a new picture.'
          : 'Pet photos updated (face, ${extras.join(', ')}).',
      modifiedByRole: modifiedByRole,
    );

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    return newPhotoUrl;
  }

  /// Weighted average of embeddings, L2-normalized (same weights as registration).
  List<double>? _fuseEmbeddings(List<(List<double>?, double)> items) {
    final valid = items.where((e) => e.$1 != null && e.$1!.isNotEmpty).toList();
    if (valid.isEmpty) return null;
    final dim = valid.first.$1!.length;
    final fused = List<double>.filled(dim, 0.0);
    for (final (emb, w) in valid) {
      for (int i = 0; i < dim; i++) {
        fused[i] += emb![i] * w;
      }
    }
    double normSq = 0.0;
    for (final v in fused) {
      normSq += v * v;
    }
    final norm = sqrt(normSq);
    if (norm > 0) {
      for (int i = 0; i < dim; i++) {
        fused[i] /= norm;
      }
    }
    return fused;
  }
}
