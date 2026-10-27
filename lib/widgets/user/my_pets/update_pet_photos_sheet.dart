import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/app_colors.dart';
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
  File? _face;
  File? _left;
  File? _right;
  File? _unique;

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
  }

  void _remove(PetPhotoSlot slot) {
    setState(() {
      switch (slot) {
        case PetPhotoSlot.face:
          _face = null;
        case PetPhotoSlot.leftBody:
          _left = null;
        case PetPhotoSlot.rightBody:
          _right = null;
        case PetPhotoSlot.uniqueFeature:
          _unique = null;
      }
    });
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
                'Re-upload the face, side profiles and unique mark so AI recognition stays accurate. Angles left empty will not be used for matching.',
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
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _face == null
                    ? null
                    : () => Navigator.pop(
                          context,
                          PetPhotoSelection(
                            face: _face!,
                            left: _left,
                            right: _right,
                            unique: _unique,
                          ),
                        ),
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
