import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_routes.dart';
import '../../../core/app_toast.dart';
import '../../../services/ai/pet_embedding_service.dart';
import '../../../widgets/user/pet_registration/pet_photo_slot_card.dart';
import '../../../widgets/user/pet_registration/pet_registration_biometrics_section.dart';
import '../../../widgets/user/pet_registration/pet_registration_fields.dart';

export '../../../widgets/user/pet_registration/pet_photo_slot_card.dart';
export '../../../widgets/user/pet_registration/pet_registration_biometrics_section.dart';
export '../../../widgets/user/pet_registration/pet_registration_fields.dart';

/// Pet Registration screen – saves pet data and photo to Supabase.
class ProfilePetRegistrationScreen extends StatefulWidget {
  const ProfilePetRegistrationScreen({super.key});

  @override
  State<ProfilePetRegistrationScreen> createState() =>
      _ProfilePetRegistrationScreenState();
}

class _ProfilePetRegistrationScreenState
    extends State<ProfilePetRegistrationScreen> {
  final _scrollController = ScrollController();
  final _nameCtrl = TextEditingController();
  final _otherBreedCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _collarCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _selectedSpecies = 'Dog';
  String _selectedBreed = 'Aspin';
  String _selectedBarangay = 'Calatagan';
  DateTime? _selectedDOB;
  bool _isDOBUnknown = false;

  // Multi-angle biometric photos
  File? _faceImage;
  File? _leftBodyImage;
  File? _rightBodyImage;
  File? _uniqueFeatureImage;
  bool _isSaving = false;

  final _supabase = Supabase.instance.client;
  static const Set<String> _allowedSpecies = {'Dog', 'Cat'};

  @override
  void dispose() {
    _scrollController.dispose();
    _nameCtrl.dispose();
    _otherBreedCtrl.dispose();
    _colorCtrl.dispose();
    _collarCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(PetPhotoSlot slot) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select Image Source',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ImageSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ImageSourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final imgFile = File(picked.path);
      setState(() {
        switch (slot) {
          case PetPhotoSlot.face:
            _faceImage = imgFile;
            break;
          case PetPhotoSlot.leftBody:
            _leftBodyImage = imgFile;
            break;
          case PetPhotoSlot.rightBody:
            _rightBodyImage = imgFile;
            break;
          case PetPhotoSlot.uniqueFeature:
            _uniqueFeatureImage = imgFile;
            break;
        }
      });

      // Auto-detect species if the face photo was chosen
      if (slot == PetPhotoSlot.face) {
        try {
          final detected =
              await PetEmbeddingService.instance.detectSpecies(imgFile);
          if (detected['isDog'] == true && mounted) {
            setState(() => _selectedSpecies = 'Dog');
          } else if (detected['isCat'] == true && mounted) {
            setState(() => _selectedSpecies = 'Cat');
          }
        } catch (e) {
          debugPrint('[PetTrace] Auto-detect on photo pick: $e');
        }
      }
    }
  }

  void _removePhoto(PetPhotoSlot slot) {
    setState(() {
      switch (slot) {
        case PetPhotoSlot.face:
          _faceImage = null;
          break;
        case PetPhotoSlot.leftBody:
          _leftBodyImage = null;
          break;
        case PetPhotoSlot.rightBody:
          _rightBodyImage = null;
          break;
        case PetPhotoSlot.uniqueFeature:
          _uniqueFeatureImage = null;
          break;
      }
    });
  }

  /// Fuses multiple DINOv2 embeddings across angles into a single normalized 768-dim vector.
  List<double>? _fuseEmbeddings({
    required List<double>? faceEmb,
    required List<double>? leftEmb,
    required List<double>? rightEmb,
    List<double>? uniqueEmb,
  }) {
    final validList = <List<double>>[];
    final weights = <double>[];

    if (faceEmb != null && faceEmb.isNotEmpty) {
      validList.add(faceEmb);
      weights.add(1.3); // High priority on facial features
    }
    if (leftEmb != null && leftEmb.isNotEmpty) {
      validList.add(leftEmb);
      weights.add(1.0);
    }
    if (rightEmb != null && rightEmb.isNotEmpty) {
      validList.add(rightEmb);
      weights.add(1.0);
    }
    if (uniqueEmb != null && uniqueEmb.isNotEmpty) {
      validList.add(uniqueEmb);
      weights.add(1.2); // High priority on distinctive marks
    }

    if (validList.isEmpty) return null;

    final dim = validList.first.length;
    final fused = List<double>.filled(dim, 0.0);

    for (int v = 0; v < validList.length; v++) {
      final w = weights[v];
      final emb = validList[v];
      for (int i = 0; i < dim; i++) {
        fused[i] += emb[i] * w;
      }
    }

    // L2-normalize the fused vector
    double normSq = 0.0;
    for (int i = 0; i < dim; i++) {
      normSq += fused[i] * fused[i];
    }
    final norm = sqrt(normSq);
    if (norm > 0) {
      for (int i = 0; i < dim; i++) {
        fused[i] /= norm;
      }
    }

    return fused;
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? now.subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            surface: AppColors.surface,
            onSurface: AppColors.onSurface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDOB = picked;
        _isDOBUnknown = false;
      });
    }
  }

  Future<void> _savePet() async {
    // Validate required fields
    final petName = _nameCtrl.text.trim();
    if (petName.isEmpty) {
      _showError('Please enter your pet\'s name.');
      return;
    }
    if (petName.length < 2) {
      _showError('Pet name must be at least 2 characters.');
      return;
    }
    if (petName.length > 40) {
      _showError('Pet name cannot exceed 40 characters.');
      return;
    }
    if (!RegExp(r'[a-zA-ZñÑ]').hasMatch(petName)) {
      _showError('Pet name must include letters (cannot be numbers only).');
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9ñÑ\s\.\-']+$").hasMatch(petName)) {
      _showError(
          'Pet name can only contain letters, numbers, spaces, and hyphens.');
      return;
    }

    final breedVal = _selectedBreed == 'Other'
        ? _otherBreedCtrl.text.trim()
        : _selectedBreed;
    if (_selectedBreed == 'Other' && breedVal.isEmpty) {
      _showError('Please specify the breed name.');
      return;
    }
    if (breedVal.isNotEmpty && breedVal.length > 50) {
      _showError('Breed cannot exceed 50 characters.');
      return;
    }

    final colorVal = _colorCtrl.text.trim();
    if (colorVal.isNotEmpty && colorVal.length > 50) {
      _showError('Color description cannot exceed 50 characters.');
      return;
    }

    final weightVal = _weightCtrl.text.trim();
    if (weightVal.isNotEmpty && weightVal.toUpperCase() != 'N/A') {
      final parsed = double.tryParse(weightVal);
      if (parsed == null || parsed <= 0 || parsed > 200) {
        _showError('Please enter a realistic weight in kg (e.g. 5.5).');
        return;
      }
    }

    if (_faceImage == null) {
      _showError('Please upload a Face / Front photo of your pet.');
      return;
    }
    if (_selectedSpecies == null ||
        !_allowedSpecies.contains(_selectedSpecies)) {
      _showError('Only dogs and cats can be registered.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final detected =
          await PetEmbeddingService.instance.detectSpecies(_faceImage!);
      if (detected['isAccepted'] != true) {
        _showError(_buildRegistrationRejectionMessage(detected));
        return;
      }

      final selectedSpecies = _selectedSpecies!;
      final isDog = detected['isDog'] == true;
      final isCat = detected['isCat'] == true;

      final mismatch = (selectedSpecies.toLowerCase() == 'dog' && !isDog) ||
          (selectedSpecies.toLowerCase() == 'cat' && !isCat);

      if (mismatch) {
        _showError(
          'Species mismatch: You selected "$selectedSpecies" but AI detected "${detected['label']}". Please select the matching species or upload another photo.',
        );
        return;
      }

      // Check collar uniqueness if entered (1 collar for 1 pet rule)
      final collarText = _collarCtrl.text.trim();
      if (collarText.isNotEmpty && collarText.toUpperCase() != 'N/A') {
        final existingPet = await _supabase
            .from('pets')
            .select('pet_id, name')
            .eq('gps_id', collarText)
            .maybeSingle();

        if (existingPet != null) {
          final otherName = existingPet['name'] ?? 'another pet';
          _showError(
            'Collar "$collarText" is already paired to "$otherName". A collar can only belong to 1 pet.',
          );
          return;
        }
      }

      // Clear any previous location history for this collar so newly registered pet starts fresh
      if (collarText.isNotEmpty && collarText.toUpperCase() != 'N/A') {
        try {
          await _supabase
              .from('gps_locations')
              .delete()
              .eq('gps_id', collarText);
        } catch (_) {}
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');

      Future<String> uploadPhoto(File file, String prefix) async {
        final fileExt = file.path.split('.').last;
        final fileName = 'pets/${timestamp}_${prefix}_$randomSuffix.$fileExt';
        await _supabase.storage.from('pet-photos').upload(fileName, file);
        return _supabase.storage.from('pet-photos').getPublicUrl(fileName);
      }

      final photoUrl = await uploadPhoto(_faceImage!, 'face');
      if (_leftBodyImage != null) {
        await uploadPhoto(_leftBodyImage!, 'left');
      }
      if (_rightBodyImage != null) {
        await uploadPhoto(_rightBodyImage!, 'right');
      }
      if (_uniqueFeatureImage != null) {
        await uploadPhoto(_uniqueFeatureImage!, 'unique');
      }

      final breedText = _selectedBreed == 'Other'
          ? (_otherBreedCtrl.text.trim().isEmpty ? 'Other' : _otherBreedCtrl.text.trim())
          : _selectedBreed;
      final colorText = _colorCtrl.text.trim();
      final weightText = _weightCtrl.text.trim();

      // Step 3: Insert row into 'pets' table (face photo is primary photo_url)
      final insertedRows = await _supabase
          .from('pets')
          .insert({
            'owner_id': _supabase.auth.currentUser!.id,
            'name': _nameCtrl.text.trim(),
            'species': selectedSpecies,
            'breed': breedText.isEmpty ? 'N/A' : breedText,
            'color': colorText.isEmpty ? 'N/A' : colorText,
            'weight': (weightText.isEmpty || weightText.toUpperCase() == 'N/A')
                ? 0.0
                : (double.tryParse(weightText) ?? 0.0),
            'date_of_birth': (_isDOBUnknown || _selectedDOB == null)
                ? null
                : _selectedDOB!.toIso8601String(),
            'barangay': _selectedBarangay,
            'gps_id':
                (collarText.isEmpty || collarText.toUpperCase() == 'N/A')
                    ? null
                    : collarText,
            'photo_url': photoUrl,
            'status': 'active',
          })
          .select('pet_id')
          .single();

      // Step 4: Extract multi-angle DINOv2 embeddings and fuse into a rich 768-dim vector
      final petId = insertedRows['pet_id']?.toString();
      debugPrint('[PetTrace] Pet inserted with ID: $petId');

      if (petId != null) {
        try {
          debugPrint('[PetTrace] Starting multi-angle embedding generation...');
          final faceEmb =
              await PetEmbeddingService.instance.extractEmbedding(_faceImage!);
          List<double>? leftEmb;
          if (_leftBodyImage != null) {
            leftEmb = await PetEmbeddingService.instance
                .extractEmbedding(_leftBodyImage!);
          }
          List<double>? rightEmb;
          if (_rightBodyImage != null) {
            rightEmb = await PetEmbeddingService.instance
                .extractEmbedding(_rightBodyImage!);
          }
          List<double>? uniqueEmb;
          if (_uniqueFeatureImage != null) {
            uniqueEmb = await PetEmbeddingService.instance
                .extractEmbedding(_uniqueFeatureImage!);
          }

          final fused = _fuseEmbeddings(
            faceEmb: faceEmb,
            leftEmb: leftEmb,
            rightEmb: rightEmb,
            uniqueEmb: uniqueEmb,
          );

          if (fused != null) {
            debugPrint(
                '[PetTrace] Fused multi-angle embedding generated (${fused.length} dims), saving...');
            await _supabase
                .from('pets')
                .update({'embedding': fused}).eq('pet_id', petId);
            debugPrint('[PetTrace] Multi-angle embedding saved successfully!');
          } else {
            debugPrint('[PetTrace] WARNING: Fused embedding returned null!');
          }
        } catch (embErr) {
          debugPrint('[PetTrace] Embedding extraction/saving error: $embErr');
        }
      }

      if (!mounted) return;

      AppToast.success(
        context,
        '${_nameCtrl.text.trim()} registered successfully with multi-angle biometrics!',
      );

      Navigator.pushReplacementNamed(context, AppRoutes.myPets);
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _buildRegistrationRejectionMessage(Map<String, dynamic> detected) {
    final label = (detected['label'] ?? '').toString().trim();
    if (label.isEmpty || label.toLowerCase() == 'not a pet') {
      return 'Registration rejected: Photo is unrecognizable. Please upload a clear, well-lit photo that shows a supported dog or cat.';
    }
    return 'Registration rejected: PetTrace only supports Dogs and Cats. Detected: "$label".';
  }

  void _showError(String message) {
    AppToast.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              children: [
                _buildRegistrationForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding:
          EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Pet Registration',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: AppColors.surfaceContainerHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Biometric Photos Section
          PetRegistrationBiometricsSection(
            faceImage: _faceImage,
            leftBodyImage: _leftBodyImage,
            rightBodyImage: _rightBodyImage,
            uniqueFeatureImage: _uniqueFeatureImage,
            onPickImage: _pickImage,
            onRemoveImage: _removePhoto,
          ),
          const SizedBox(height: 20),

          // Name + species
          Row(children: [
            Expanded(
              child: PetFormField(
                label: 'Pet Name',
                controller: _nameCtrl,
                hint: 'e.g. Buster',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PetSpeciesDropdown(
                selectedSpecies: _selectedSpecies,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedSpecies = v;
                    _selectedBreed = (v == 'Cat') ? 'Puspin' : 'Aspin';
                    _otherBreedCtrl.clear();
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Breed + Color
          Row(children: [
            Expanded(
              child: PetBreedDropdown(
                selectedSpecies: _selectedSpecies,
                selectedBreed: _selectedBreed,
                onBreedChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedBreed = v;
                    if (v != 'Other') {
                      _otherBreedCtrl.clear();
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PetFormField(
                label: 'Color',
                controller: _colorCtrl,
                hint: 'e.g. Tri-color (or N/A)',
              ),
            ),
          ]),
          if (_selectedBreed == 'Other') ...[
            const SizedBox(height: 12),
            PetFormField(
              label: 'Specify Breed',
              controller: _otherBreedCtrl,
              hint: 'e.g. Japanese Spitz, Corgi, Sphynx, etc.',
            ),
          ],
          const SizedBox(height: 12),

          // Weight + Date of Birth
          Row(children: [
            Expanded(
              child: PetFormField(
                label: 'Weight (kg)',
                controller: _weightCtrl,
                hint: 'e.g. 12.5 (or N/A)',
                isNumber: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PetDobField(
                selectedDOB: _selectedDOB,
                isDOBUnknown: _isDOBUnknown,
                onPickDOB: _pickDOB,
                onToggleUnknown: () {
                  setState(() {
                    _isDOBUnknown = !_isDOBUnknown;
                    if (_isDOBUnknown) {
                      _selectedDOB = null;
                    }
                  });
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Barangay dropdown
          PetBarangayDropdown(
            selectedBarangay: _selectedBarangay,
            onChanged: (v) => setState(() => _selectedBarangay = v),
          ),
          const SizedBox(height: 12),

          // Collar ID
          PetFormField(
            label: 'Link GPS ID',
            controller: _collarCtrl,
            hint: 'Scan or enter ID (or N/A)',
          ),
          const SizedBox(height: 6),
          Text(
            'This ID connects the GPS hardware to the System.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _savePet,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(_isSaving ? 'Saving...' : 'Save Pet'),
            ),
          ),
        ],
      ),
    );
  }
}
