import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
import '../../../services/ai/pet_embedding_service.dart';
import '../../../services/pets/pet_photo_service.dart';
import '../pet_registration/pet_photo_slot_card.dart';
import '../pet_registration/pet_registration_biometrics_section.dart';

/// Selected images returned by [UpdatePetPhotosSheet].
class PetPhotoSelection {
  final File face;
  final File? left;
  final File? right;
  final File? unique;
  const PetPhotoSelection({
    required this.face,
    this.left,
    this.right,
    this.unique,
  });
}

/// Bottom sheet to re-upload the face, left/right sides and unique mark photos.
class UpdatePetPhotosSheet extends StatefulWidget {
  const UpdatePetPhotosSheet({super.key});

  static Future<PetPhotoSelection?> show(BuildContext context) {
    return showModalBottomSheet<PetPhotoSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const UpdatePetPhotosSheet(),
    );
  }

  @override
  State<UpdatePetPhotosSheet> createState() => _UpdatePetPhotosSheetState();
}

class _UpdatePetPhotosSheetState extends State<UpdatePetPhotosSheet> {
  static const double _kSimilarityThreshold = 0.75;

  File? _face;
  File? _left;
  File? _right;
  File? _unique;

  final Map<PetPhotoSlot, bool> _slotValidating = {};
  final Map<PetPhotoSlot, bool?> _slotValid = {};
  final Map<PetPhotoSlot, double?> _slotSimilarity = {};
  final Map<PetPhotoSlot, String?> _slotError = {};
  final Map<PetPhotoSlot, List<double>?> _slotEmbeddings = {};

  Future<void> _pick(PetPhotoSlot slot) async {
    final file = await PetPhotoService.instance.pickPetImage(context);
    if (file == null || !mounted) return;
    setState(() {
      switch (slot) {
        case PetPhotoSlot.face:
          _face = file;
        case PetPhotoSlot.leftBody:
          _left = file;
        case PetPhotoSlot.rightBody:
          _right = file;
        case PetPhotoSlot.uniqueFeature:
          _unique = file;
      }
    });

    await _validateSlot(slot, file);
  }

  Future<void> _validateSlot(PetPhotoSlot slot, File file) async {
    setState(() {
      _slotValidating[slot] = true;
      _slotValid[slot] = null;
      _slotSimilarity[slot] = null;
      _slotError[slot] = null;
    });

    try {
      final detected = await PetEmbeddingService.instance.detectSpecies(file);
      final isAccepted = detected['isAccepted'] == true;
      final isDog = detected['isDog'] == true;
      final isCat = detected['isCat'] == true;

      if (!isAccepted || (!isDog && !isCat)) {
        if (mounted) {
          setState(() {
            _slotValid[slot] = false;
            _slotError[slot] = 'Not recognized as a pet';
            _slotEmbeddings[slot] = null;
          });
        }
        return;
      }

      final emb = await PetEmbeddingService.instance.extractEmbedding(file);
      if (!mounted) return;
      if (emb == null) {
        setState(() {
          _slotValid[slot] = false;
          _slotError[slot] = 'Embedding failed';
          _slotEmbeddings[slot] = null;
        });
        return;
      }
      _slotEmbeddings[slot] = emb;

      if (slot == PetPhotoSlot.face) {
        setState(() {
          _slotValid[slot] = true;
          _slotSimilarity[slot] = 1.0;
          _slotError[slot] = null;
        });
        await _revalidateSecondarySlots();
      } else {
        final faceEmb = _slotEmbeddings[PetPhotoSlot.face];
        if (faceEmb != null) {
          final sim = PetEmbeddingService.cosineSimilarity(faceEmb, emb);
          final passes = sim >= _kSimilarityThreshold;
          setState(() {
            _slotSimilarity[slot] = sim;
            _slotValid[slot] = passes;
            _slotError[slot] = passes
                ? null
                : 'Mismatch (${(sim * 100).toStringAsFixed(0)}% < 75%)';
          });
        } else {
          setState(() {
            _slotValid[slot] = null;
            _slotSimilarity[slot] = null;
            _slotError[slot] = 'Upload face photo to verify';
          });
        }
      }
    } catch (e) {
      debugPrint('[PetTrace] Update sheet slot validation error: $e');
      if (mounted) {
        setState(() {
          _slotValid[slot] = false;
          _slotError[slot] = 'Recognition failed';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _slotValidating[slot] = false;
        });
      }
    }
  }

  Future<void> _revalidateSecondarySlots() async {
    final faceEmb = _slotEmbeddings[PetPhotoSlot.face];
    if (faceEmb == null) return;

    for (final slot in [
      PetPhotoSlot.leftBody,
      PetPhotoSlot.rightBody,
      PetPhotoSlot.uniqueFeature,
    ]) {
      final emb = _slotEmbeddings[slot];
      if (emb != null) {
        final sim = PetEmbeddingService.cosineSimilarity(faceEmb, emb);
        final passes = sim >= _kSimilarityThreshold;
        if (mounted) {
          setState(() {
            _slotSimilarity[slot] = sim;
            _slotValid[slot] = passes;
            _slotError[slot] = passes
                ? null
                : 'Mismatch (${(sim * 100).toStringAsFixed(0)}% < 75%)';
          });
        }
      }
    }
  }

  void _remove(PetPhotoSlot slot) {
    setState(() {
      _slotValidating[slot] = false;
      _slotValid[slot] = null;
      _slotSimilarity[slot] = null;
      _slotError[slot] = null;
      _slotEmbeddings[slot] = null;

      switch (slot) {
        case PetPhotoSlot.face:
          _face = null;
          for (final s in [
            PetPhotoSlot.leftBody,
            PetPhotoSlot.rightBody,
            PetPhotoSlot.uniqueFeature
          ]) {
            if (_slotEmbeddings[s] != null) {
              _slotValid[s] = null;
              _slotSimilarity[s] = null;
              _slotError[s] = 'Upload face photo to verify';
            }
          }
        case PetPhotoSlot.leftBody:
          _left = null;
        case PetPhotoSlot.rightBody:
          _right = null;
        case PetPhotoSlot.uniqueFeature:
          _unique = null;
      }
    });
  }

  bool get _canSave {
    if (_face == null) return false;
    if (_slotValidating.values.any((v) => v)) return false;
    if (_slotValid[PetPhotoSlot.face] == false) return false;
    if (_left != null && _slotValid[PetPhotoSlot.leftBody] == false) return false;
    if (_right != null && _slotValid[PetPhotoSlot.rightBody] == false) return false;
    if (_unique != null && _slotValid[PetPhotoSlot.uniqueFeature] == false) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                'Update Pet Photos',
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Re-upload face, side profiles, and unique markings. Photos are analyzed with AI to ensure they match the same pet (≥ 75% match threshold).',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: PetRegistrationBiometricsSection(
                    faceImage: _face,
                    leftBodyImage: _left,
                    rightBodyImage: _right,
                    uniqueFeatureImage: _unique,
                    onPickImage: _pick,
                    onRemoveImage: _remove,
                    slotValidating: _slotValidating,
                    slotValid: _slotValid,
                    slotSimilarity: _slotSimilarity,
                    slotError: _slotError,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _canSave
                    ? () => Navigator.pop(
                          context,
                          PetPhotoSelection(
                            face: _face!,
                            left: _left,
                            right: _right,
                            unique: _unique,
                          ),
                        )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Save Photos',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
