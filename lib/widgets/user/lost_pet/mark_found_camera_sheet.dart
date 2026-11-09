import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../services/ai/pet_embedding_service.dart';

/// Result returned when a user successfully captures and confirms a found pet.
class MarkFoundResult {
  final String photoUrl;
  final double? similarity;
  final bool appearanceChanged;
  final String? changeReason;

  const MarkFoundResult({
    required this.photoUrl,
    this.similarity,
    this.appearanceChanged = false,
    this.changeReason,
  });
}

/// Modal bottom sheet allowing an owner to capture or pick a proof photo
/// of their found pet before marking the report as resolved/found.
class MarkFoundCameraSheet extends StatefulWidget {
  final String petName;
  final String reportId;
  final Map<String, dynamic>? petData;
  final dynamic petId;

  const MarkFoundCameraSheet({
    super.key,
    required this.petName,
    required this.reportId,
    this.petData,
    this.petId,
  });

  /// Displays the sheet and returns the MarkFoundResult with photo URL, similarity,
  /// and appearance change confirmations, or null if cancelled.
  static Future<MarkFoundResult?> show(
    BuildContext context, {
    required String petName,
    required String reportId,
    Map<String, dynamic>? petData,
    dynamic petId,
  }) {
    return showModalBottomSheet<MarkFoundResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarkFoundCameraSheet(
        petName: petName,
        reportId: reportId,
        petData: petData,
        petId: petId,
      ),
    );
  }

  @override
  State<MarkFoundCameraSheet> createState() => _MarkFoundCameraSheetState();
}

class _MarkFoundCameraSheetState extends State<MarkFoundCameraSheet> {
  final _picker = ImagePicker();
  File? _capturedImage;
  bool _isUploading = false;
  String? _uploadStatusText;

  // AI Verification State
  bool _isValidatingAi = false;
  bool? _isPetDetected;
  String? _detectedSpecies;
  String? _aiServerError;

  // Similarity & Changed Appearance State
  List<double>? _targetEmbedding;
  double? _similarity;
  bool _isHighMatch = false;
  bool _isAppearanceChanged = false;
  bool _isMismatch = false;
  bool _confirmedAppearanceChanged = false;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _resolveTargetEmbedding();
  }

  Future<void> _resolveTargetEmbedding() async {
    // 1. Check if embedding is present in widget.petData
    final rawEmb = widget.petData?['embedding'];
    if (rawEmb != null) {
      _targetEmbedding = _parseEmbedding(rawEmb);
    }

    // 2. If null, fetch from database using petId or reportId
    if (_targetEmbedding == null) {
      try {
        String? petId = (widget.petId ?? widget.petData?['pet_id'])?.toString();
        if (petId == null || petId.isEmpty) {
          final rep = await Supabase.instance.client
              .from('lost_reports')
              .select('pet_id, photo_url')
              .eq('report_id', widget.reportId)
              .maybeSingle();
          petId = rep?['pet_id']?.toString();
        }

        if (petId != null && petId.isNotEmpty) {
          final petRow = await Supabase.instance.client
              .from('pets')
              .select('embedding, photo_url')
              .eq('pet_id', widget.petId ?? widget.petData?['pet_id'] ?? petId)
              .maybeSingle();
          if (petRow != null && petRow['embedding'] != null) {
            _targetEmbedding = _parseEmbedding(petRow['embedding']);
          }
        }
      } catch (e) {
        debugPrint('[MarkFound] Error resolving pet embedding: $e');
      }
    }
  }

  List<double>? _parseEmbedding(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => (e as num).toDouble()).toList();
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => (e as num).toDouble()).toList();
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        final file = File(picked.path);
        setState(() {
          _capturedImage = file;
          _isPetDetected = null;
          _detectedSpecies = null;
          _aiServerError = null;
          _similarity = null;
          _isHighMatch = false;
          _isAppearanceChanged = false;
          _isMismatch = false;
          _confirmedAppearanceChanged = false;
          _selectedReason = null;
          _isValidatingAi = true;
        });

        // Run AI verification automatically upon picking
        await _verifyPhotoWithAi(file);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not access camera/gallery: $e');
      }
    }
  }

  Future<void> _verifyPhotoWithAi(File file) async {
    setState(() {
      _isValidatingAi = true;
      _aiServerError = null;
    });
    try {
      // Step 1: Detect species (Dog or Cat)
      final detected =
          await PetEmbeddingService.instance.detectSpecies(file);
      final isAccepted = detected['isAccepted'] == true;
      final isDog = detected['isDog'] == true;
      final isCat = detected['isCat'] == true;
      final species =
          isDog ? 'Dog' : (isCat ? 'Cat' : (detected['species']?.toString() ?? ''));

      if (!isAccepted || (!isDog && !isCat)) {
        if (!mounted) return;
        setState(() {
          _isPetDetected = false;
          _detectedSpecies = species;
          _isValidatingAi = false;
        });
        AppToast.error(
          context,
          'No pet detected! Please capture a clear photo of your recovered pet.',
        );
        return;
      }

      _isPetDetected = true;
      _detectedSpecies = species;

      // Step 2: Extract embedding of newly captured photo
      if (_targetEmbedding == null) {
        await _resolveTargetEmbedding();
      }
      final newEmbedding =
          await PetEmbeddingService.instance.extractEmbedding(file);
      if (newEmbedding == null) {
        if (!mounted) return;
        setState(() {
          _isValidatingAi = false;
          _isPetDetected = null;
          _isHighMatch = false;
          _aiServerError =
              'Failed to extract biometric features from photo. Please retry or take a clearer photo.';
        });
        AppToast.error(context, _aiServerError!);
        return;
      }

      // Step 3: Compare with registered pet embedding
      if (_targetEmbedding != null && _targetEmbedding!.isNotEmpty) {
        final sim = PetEmbeddingService.cosineSimilarity(
            newEmbedding, _targetEmbedding!);
        final clampedSim = sim.clamp(0.0, 1.0);
        _similarity = clampedSim;

        if (clampedSim >= 0.75) {
          _isHighMatch = true;
          _isAppearanceChanged = false;
          _isMismatch = false;
        } else if (clampedSim >= 0.45) {
          _isHighMatch = false;
          _isAppearanceChanged = true;
          _isMismatch = false;
        } else {
          _isHighMatch = false;
          _isAppearanceChanged = false;
          _isMismatch = true;
        }
      } else {
        // Fallback: If pet had no precomputed embedding in DB, allow species match
        _isHighMatch = true;
        _similarity = null;
      }

      if (!mounted) return;
      setState(() {
        _isValidatingAi = false;
      });
    } catch (e) {
      debugPrint('[MarkFound] AI verification error: $e');
      if (!mounted) return;
      setState(() {
        _isValidatingAi = false;
        _isPetDetected = null;
        _isHighMatch = false;
        _isAppearanceChanged = false;
        _isMismatch = false;
        _aiServerError =
            'Could not connect to the AI verification server. It may be offline. Please try again.';
      });
      AppToast.error(
        context,
        'AI server is unreachable. Verification is required before marking as found.',
      );
    }
  }

  Future<void> _showNotAPetDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon Header
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEE2E2), Color(0xFFFCA5A5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.no_photography_rounded,
                    size: 34,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Only Pets Allowed',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'The AI vision model did not detect a pet (dog or cat) in this photo. Non-pet items, objects, or people cannot be accepted as proof of recovery.\n\nPlease snap a clear, well-lit photo of ${widget.petName.isNotEmpty ? widget.petName : "your recovered pet"}.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickPhoto(ImageSource.camera);
                  },
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(
                    'Retake Photo with Camera',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_capturedImage == null) return false;
    if (_isUploading || _isValidatingAi) return false;
    if (_aiServerError != null) return false;
    if (_isPetDetected != true) return false;
    if (_isMismatch) return false;
    if (_isAppearanceChanged && !_confirmedAppearanceChanged) return false;
    return true;
  }

  Future<void> _confirmAndUpload() async {
    if (_capturedImage == null) {
      AppToast.error(
          context, 'Please capture or select a photo of your pet first.');
      return;
    }

    if (!_canSubmit) {
      if (_aiServerError != null) {
        await _verifyPhotoWithAi(_capturedImage!);
      } else if (_isMismatch) {
        AppToast.error(
          context,
          'This photo does not match ${widget.petName} (< 45% similarity). Please retake a photo of your pet.',
        );
      } else if (_isAppearanceChanged && !_confirmedAppearanceChanged) {
        AppToast.info(
          context,
          'Please confirm your pet\'s appearance change below before submitting.',
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusText = 'Uploading verification photo…';
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
      final ext = _capturedImage!.path.split('.').last;
      final cleanExt = (ext.isEmpty || ext.length > 5) ? 'jpg' : ext;
      final fileName =
          'found_reports/found_${widget.reportId}_${timestamp}_$randomSuffix.$cleanExt';

      final storage = Supabase.instance.client.storage.from('pet-photos');
      await storage.upload(fileName, _capturedImage!);
      final publicUrl = storage.getPublicUrl(fileName);

      if (!mounted) return;
      Navigator.pop(
        context,
        MarkFoundResult(
          photoUrl: publicUrl,
          similarity: _similarity,
          appearanceChanged: _isAppearanceChanged,
          changeReason: _selectedReason,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      AppToast.error(context, 'Failed to upload photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            // Drag handle
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Top Icon badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF16A34A),
                size: 28,
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Text(
              'Confirm Found Pet',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please capture a live photo of ${widget.petName.isNotEmpty ? widget.petName : "your pet"} to verify recovery for the admin record.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Image Preview or Camera prompt
            if (_capturedImage != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(
                      _capturedImage!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    // Retake button pill overlay
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Material(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isUploading ? null : () => _pickPhoto(ImageSource.camera),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded,
                                    size: 15, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Retake',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isValidatingAi) ...[
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI analyzing pet features & calculating match…',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_aiServerError != null) ...[
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _aiServerError!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isPetDetected == false) ...[
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_rounded,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '✗ No pet detected. Objects, items, or people are not allowed. Please retake photo.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_isPetDetected == true) ...[
                // Tier 1: High Similarity Match (>= 75%)
                if (_isHighMatch) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDCFCE7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded,
                              color: Color(0xFF16A34A), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _similarity != null
                                    ? 'High AI Match: ${(_similarity! * 100).toStringAsFixed(1)}% Verified'
                                    : 'Pet Verified (${_detectedSpecies ?? "Pet"})',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF15803D),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Meets 75%+ requirement. Confirmed match for ${widget.petName}\'s registered features.',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFF166534),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
                // Tier 2: Changed Appearance (45% - 74%)
                else if (_isAppearanceChanged) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.help_outline_rounded,
                                  color: Color(0xFFD97706), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Similarity: ${(_similarity! * 100).toStringAsFixed(1)}% · Below 75% Threshold',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                  Text(
                                    'Has ${widget.petName}\'s appearance changed while missing?',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Confirmation Checkbox
                        InkWell(
                          onTap: () {
                            setState(() {
                              _confirmedAppearanceChanged =
                                  !_confirmedAppearanceChanged;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _confirmedAppearanceChanged,
                                    activeColor: const Color(0xFFD97706),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() =>
                                          _confirmedAppearanceChanged =
                                              val ?? false);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'I confirm this is my pet whose appearance changed',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF78350F),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Quick Reason Chips
                        if (_confirmedAppearanceChanged) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Select primary reason (optional):',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              'Lost Weight',
                              'Muddy / Dirty Fur',
                              'Shaved / Groomed',
                              'Injured / Bandaged',
                              'Dark / Flash Lighting',
                            ].map((reason) {
                              final isSel = _selectedReason == reason;
                              return ChoiceChip(
                                label: Text(reason),
                                selected: isSel,
                                selectedColor: const Color(0xFFFDE68A),
                                backgroundColor: Colors.white,
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSel
                                      ? const Color(0xFF78350F)
                                      : const Color(0xFF92400E),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSel
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFFCD34D),
                                  ),
                                ),
                                onSelected: (selected) {
                                  setState(() => _selectedReason =
                                      selected ? reason : null);
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ]
                // Tier 3: Mismatch (< 45%)
                else if (_isMismatch) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFDC2626), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mismatch: ${(_similarity! * 100).toStringAsFixed(1)}% Similarity',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'This photo does not match ${widget.petName} (< 45% similarity). Please retake a photo of your actual pet.',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
            ] else ...[
              // Prompt box to take photo
              GestureDetector(
                onTap: _isUploading ? null : () => _pickPhoto(ImageSource.camera),
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.35),
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to Open Camera',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Snap a clear picture of the recovered pet',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Gallery alternate link
              TextButton.icon(
                onPressed: _isUploading ? null : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 16),
                label: Text(
                  'Or select from gallery',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Action Buttons
            if (_capturedImage != null) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isUploading || _isValidatingAi)
                      ? null
                      : (_isPetDetected == false
                          ? () => _showNotAPetDialog()
                          : _confirmAndUpload),
                  icon: (_isUploading || _isValidatingAi)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPetDetected == false
                              ? Icons.block_rounded
                              : (_aiServerError != null
                                  ? Icons.refresh_rounded
                                  : (_canSubmit
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded)),
                          size: 20,
                        ),
                  label: Text(
                    _isUploading
                        ? (_uploadStatusText ?? 'Uploading…')
                        : _isValidatingAi
                            ? 'Analyzing Photo…'
                            : _aiServerError != null
                                ? 'AI Server Offline · Tap to Retry'
                                : _isPetDetected == false
                                    ? 'Invalid Photo (No Pet Detected)'
                                    : _isMismatch
                                        ? 'Mismatch (< 45% Similarity) · Please Retake'
                                        : (_isAppearanceChanged &&
                                                !_confirmedAppearanceChanged)
                                            ? 'Confirm Appearance Change to Proceed'
                                            : 'Confirm & Mark as Found',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isPetDetected == false ||
                            _isMismatch ||
                            _aiServerError != null)
                        ? const Color(0xFFEF4444)
                        : (_canSubmit
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFD97706)),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _isMismatch
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFE2E8F0),
                    disabledForegroundColor: _isMismatch
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFF94A3B8),
                    elevation: _canSubmit ? 2 : 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _isUploading ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
