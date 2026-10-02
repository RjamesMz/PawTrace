import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/app_toast.dart';
import '../../services/pet_embedding_service.dart';

/// Pet photo capture slot
enum PetPhotoSlot {
  face,
  leftBody,
  rightBody,
  uniqueFeature,
}

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
  final _breedCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _collarCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _selectedSpecies = 'Dog';
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
    _breedCtrl.dispose();
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
                _buildSourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                _buildSourceOption(
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

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlotCard({
    required String title,
    required String subtitle,
    required String badgeText,
    required bool isRequired,
    required IconData icon,
    required File? imageFile,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    bool isWide = false,
  }) {
    final hasImage = imageFile != null;
    final cardHeight =
        hasImage ? (isWide ? 140.0 : 130.0) : (isWide ? 88.0 : 120.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasImage
                ? Colors.transparent
                : AppColors.outlineVariant.withOpacity(0.45),
            width: 1,
          ),
          image: hasImage
              ? DecorationImage(
                  image: FileImage(imageFile),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.08),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: Stack(
          children: [
            // Empty state content
            if (!hasImage)
              Center(
                child: isWide
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 22,
                            color: AppColors.onSurfaceVariant.withOpacity(0.45),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                isRequired ? 'Required' : 'Optional',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 24,
                            color: AppColors.onSurfaceVariant.withOpacity(0.40),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface.withOpacity(0.65),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRequired ? 'Required' : 'Optional',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color:
                                  AppColors.onSurfaceVariant.withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
              ),

            // Filled state: small "✓ title" label bottom-left
            if (hasImage)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Remove button top-right
            if (hasImage)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 13),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
      _showError('Pet name can only contain letters, numbers, spaces, and hyphens.');
      return;
    }

    final breedVal = _breedCtrl.text.trim();
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
    if (_leftBodyImage == null) {
      _showError('Please upload a Left Body photo of your pet.');
      return;
    }
    if (_rightBodyImage == null) {
      _showError('Please upload a Right Body photo of your pet.');
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
            .eq('collar_id', collarText)
            .maybeSingle();

        if (existingPet != null) {
          final otherName = existingPet['name'] ?? 'another pet';
          _showError(
            'Collar "$collarText" is already paired to "$otherName". A collar can only belong to 1 pet.',
          );
          return;
        }
      }

      // Step 2: Upload all photos to Supabase Storage bucket 'pet-photos'
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');

      Future<String> uploadPhoto(File file, String prefix) async {
        final fileExt = file.path.split('.').last;
        final fileName = 'pets/${timestamp}_${prefix}_$randomSuffix.$fileExt';
        await _supabase.storage.from('pet-photos').upload(fileName, file);
        return _supabase.storage.from('pet-photos').getPublicUrl(fileName);
      }

      final photoUrl = await uploadPhoto(_faceImage!, 'face');
      await uploadPhoto(_leftBodyImage!, 'left');
      await uploadPhoto(_rightBodyImage!, 'right');
      if (_uniqueFeatureImage != null) {
        await uploadPhoto(_uniqueFeatureImage!, 'unique');
      }

      final breedText = _breedCtrl.text.trim();
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
            'collar_id':
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
          final leftEmb = await PetEmbeddingService.instance
              .extractEmbedding(_leftBodyImage!);
          final rightEmb = await PetEmbeddingService.instance
              .extractEmbedding(_rightBodyImage!);
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
          EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      color: AppColors.surface,
      child: Row(
        children: [
          Text('Pet Registration',
              style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface)),
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
          Text('Pet Registration',
              style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface)),
          const SizedBox(height: 20),
          // Biometric Photos Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_enhance_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Biometric Photos (Multi-Angle)',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upload multiple angles to train the AI to recognize your pet from any perspective. Face, Left Body, and Right Body are required.',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Slot 1: Face / Front View (Required - Primary)
          _buildPhotoSlotCard(
            title: 'Face / Front View',
            subtitle: 'Clear, front-facing photo of face, eyes, and snout',
            badgeText: 'REQUIRED • PRIMARY',
            isRequired: true,
            icon: Icons.face_retouching_natural_rounded,
            imageFile: _faceImage,
            isWide: true,
            onTap: () => _pickImage(PetPhotoSlot.face),
            onRemove: () => setState(() => _faceImage = null),
          ),
          const SizedBox(height: 12),

          // Slots 2 & 3: Left Body and Right Body
          Row(
            children: [
              Expanded(
                child: _buildPhotoSlotCard(
                  title: 'Left Body Profile',
                  subtitle: 'Left side coat & pattern',
                  badgeText: 'REQUIRED',
                  isRequired: true,
                  icon: Icons.pets_rounded,
                  imageFile: _leftBodyImage,
                  onTap: () => _pickImage(PetPhotoSlot.leftBody),
                  onRemove: () => setState(() => _leftBodyImage = null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPhotoSlotCard(
                  title: 'Right Body Profile',
                  subtitle: 'Right side coat & pattern',
                  badgeText: 'REQUIRED',
                  isRequired: true,
                  icon: Icons.pets_rounded,
                  imageFile: _rightBodyImage,
                  onTap: () => _pickImage(PetPhotoSlot.rightBody),
                  onRemove: () => setState(() => _rightBodyImage = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slot 4: Unique Identification / Distinctive Mark (Optional)
          _buildPhotoSlotCard(
            title: 'Unique Mark / Distinctive Feature',
            subtitle:
                'Optional: Unique spot, chest patch, tail color, ear notch, or scar for AI boost',
            badgeText: 'OPTIONAL • AI BOOST',
            isRequired: false,
            icon: Icons.stars_rounded,
            imageFile: _uniqueFeatureImage,
            isWide: true,
            onTap: () => _pickImage(PetPhotoSlot.uniqueFeature),
            onRemove: () => setState(() => _uniqueFeatureImage = null),
          ),
          const SizedBox(height: 20),
          // Name + species
          Row(children: [
            Expanded(child: _formField('Pet Name', _nameCtrl, 'e.g. Buster')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formLabel('Species'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _allowedSpecies.contains(_selectedSpecies)
                          ? _selectedSpecies
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
                      onChanged: (v) => setState(() => _selectedSpecies = v),
                      validator: (v) => v == null
                          ? 'PetTrace only supports Dogs and Cats'
                          : null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor:
                            AppColors.secondaryContainer.withOpacity(0.3),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.onSurface),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _formField('Breed', _breedCtrl, 'e.g. Beagle (or N/A)')),
            const SizedBox(width: 12),
            Expanded(
                child:
                    _formField('Color', _colorCtrl, 'e.g. Tri-color (or N/A)')),
          ]),
          const SizedBox(height: 12),
          // Weight + Date of Birth
          Row(children: [
            Expanded(
                child: _formField(
                    'Weight (kg)', _weightCtrl, 'e.g. 12.5 (or N/A)',
                    isNumber: false)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _formLabel('Date of Birth'),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _pickDOB,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _isDOBUnknown
                                    ? 'N/A'
                                    : (_selectedDOB != null
                                        ? '${_selectedDOB!.day}/${_selectedDOB!.month}/${_selectedDOB!.year}'
                                        : 'Date / N/A'),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: _isDOBUnknown
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: (_isDOBUnknown || _selectedDOB != null)
                                      ? AppColors.onSurface
                                      : AppColors.onSurfaceVariant
                                          .withOpacity(0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isDOBUnknown = !_isDOBUnknown;
                                  if (_isDOBUnknown) {
                                    _selectedDOB = null;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isDOBUnknown
                                      ? AppColors.primary
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _isDOBUnknown
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
                                    color: _isDOBUnknown
                                        ? Colors.white
                                        : AppColors.primary,
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
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Barangay dropdown
          _formLabel('Barangay'),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedBarangay,
            items: AppConstants.barangays
                .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m,
                        style: GoogleFonts.inter(fontSize: 14),
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _selectedBarangay = v!),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.secondaryContainer.withOpacity(0.3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                      color: AppColors.primaryContainer, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
          ),
          const SizedBox(height: 12),
          // Collar ID
          _formLabel('Link Collar ID'),
          const SizedBox(height: 6),
          TextField(
            controller: _collarCtrl,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'Scan or enter ID (or N/A)',
              hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant.withOpacity(0.5)),
              filled: true,
              fillColor: AppColors.secondaryContainer.withOpacity(0.3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                      color: AppColors.primaryContainer, width: 2)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon:
                  const Icon(Icons.qr_code_scanner, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 6),
          Text('This ID helps anyone who finds your pet contact you instantly.',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 16),
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
                          color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.save, size: 20),
              label: Text(_isSaving ? 'Saving...' : 'Save Pet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formField(String label, TextEditingController ctrl, String hint,
      {bool isNumber = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _formLabel(label),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
              fontSize: 14, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
          filled: true,
          fillColor: AppColors.secondaryContainer.withOpacity(0.3),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                  color: AppColors.primaryContainer, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    ]);
  }

  Widget _formLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant),
      );
}
