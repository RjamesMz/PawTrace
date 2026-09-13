import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../services/pet_embedding_service.dart';
import '../../widgets/bottom_nav_bar.dart';

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
  File? _selectedImage;
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

  Future<void> _pickImage() async {
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
      setState(() => _selectedImage = imgFile);
      try {
        final detected =
            await PetEmbeddingService.instance.detectSpecies(imgFile);
        if (detected['isDog'] == true && mounted) {
          setState(() => _selectedSpecies = 'Dog');
        } else if (detected['isCat'] == true && mounted) {
          setState(() => _selectedSpecies = 'Cat');
        }
      } catch (e) {
        debugPrint('[PawTrace] Auto-detect on photo pick: $e');
      }
    }
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
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Please enter your pet\'s name.');
      return;
    }
    if (_selectedImage == null) {
      _showError('Please select a pet photo.');
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
          await PetEmbeddingService.instance.detectSpecies(_selectedImage!);
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

      // Step 2: Upload photo to Supabase Storage bucket 'pet-photos'
      final fileExt = _selectedImage!.path.split('.').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
      final fileName = 'pets/${timestamp}_$randomSuffix.$fileExt';

      await _supabase.storage
          .from('pet-photos')
          .upload(fileName, _selectedImage!);

      // Step 3: Get public URL of uploaded photo
      final photoUrl =
          _supabase.storage.from('pet-photos').getPublicUrl(fileName);

      final breedText = _breedCtrl.text.trim();
      final colorText = _colorCtrl.text.trim();
      final weightText = _weightCtrl.text.trim();
      final collarText = _collarCtrl.text.trim();

      // Step 4: Insert row into 'pets' table (allowing N/A / null for unknown values)
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

      // Step 5: Generate on-device AI embedding and save it
      final petId = insertedRows['pet_id']?.toString();
      debugPrint('[PawTrace] Pet inserted with ID: $petId');

      if (petId != null) {
        try {
          debugPrint('[PawTrace] Starting embedding generation...');
          final embedding = await PetEmbeddingService.instance
              .extractEmbedding(_selectedImage!);
          if (embedding != null) {
            debugPrint(
                '[PawTrace] Embedding generated (${embedding.length} dims), saving...');
            await _supabase
                .from('pets')
                .update({'embedding': embedding}).eq('pet_id', petId);
            debugPrint('[PawTrace] Embedding saved successfully!');
          } else {
            debugPrint('[PawTrace] WARNING: extractEmbedding returned null!');
          }
        } catch (embErr) {
          debugPrint('[PawTrace] Embedding error: $embErr');
          // Pet was still saved successfully — embedding can be retried
        }
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameCtrl.text.trim()} registered successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      // Navigate to MyPetsScreen replacing current route
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
    return 'Registration rejected: PawTrace only supports Dogs and Cats. Detected: "$label".';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _buildRegistrationForm(),
              ],
            ),
          ),
          const BottomNavBar(currentIndex: 3),
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
          // Photo upload area
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outlineVariant, width: 1.5),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          const Icon(Icons.add_a_photo_outlined,
                              size: 40, color: AppColors.outline),
                          const SizedBox(height: 8),
                          Text('Tap to Upload Pet Photo',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.onSurfaceVariant)),
                        ])
                  : Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
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
                          child: Text('🐶 Dog'),
                        ),
                        DropdownMenuItem(
                          value: 'Cat',
                          child: Text('🐱 Cat'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedSpecies = v),
                      validator: (v) => v == null
                          ? 'PawTrace only supports Dogs and Cats'
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
