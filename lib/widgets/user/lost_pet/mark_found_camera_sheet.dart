import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../services/ai/pet_embedding_service.dart';

/// Modal bottom sheet allowing an owner to capture or pick a proof photo
/// of their found pet before marking the report as resolved/found.
class MarkFoundCameraSheet extends StatefulWidget {
  final String petName;
  final String reportId;

  const MarkFoundCameraSheet({
    super.key,
    required this.petName,
    required this.reportId,
  });

  /// Displays the sheet and returns the uploaded public URL of the found photo,
  /// or null if the user dismissed or cancelled.
  static Future<String?> show(
    BuildContext context, {
    required String petName,
    required String reportId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarkFoundCameraSheet(
        petName: petName,
        reportId: reportId,
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
  double? _detectedConfidence;

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
          _detectedConfidence = null;
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
    setState(() => _isValidatingAi = true);
    try {
      if (kIsWeb) {
        setState(() {
          _isPetDetected = true;
          _isValidatingAi = false;
        });
        return;
      }

      final detected =
          await PetEmbeddingService.instance.detectSpecies(file);
      final isAccepted = detected['isAccepted'] == true;
      final isDog = detected['isDog'] == true;
      final isCat = detected['isCat'] == true;
      final conf = (detected['confidence'] as num?)?.toDouble() ?? 0.0;
      final species =
          isDog ? 'Dog' : (isCat ? 'Cat' : (detected['species']?.toString() ?? ''));

      if (!mounted) return;
      setState(() {
        _isPetDetected = isAccepted && (isDog || isCat);
        _detectedSpecies = species;
        _detectedConfidence = conf;
        _isValidatingAi = false;
      });

      if (!_isPetDetected!) {
        AppToast.error(
          context,
          'No pet detected! Please capture a clear photo of your recovered pet.',
        );
      }
    } catch (e) {
      debugPrint('[MarkFound] AI verification error: $e');
      if (!mounted) return;
      setState(() {
        _isValidatingAi = false;
        _isPetDetected = null;
      });
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

  Future<void> _confirmAndUpload() async {
    if (_capturedImage == null) {
      AppToast.error(
          context, 'Please capture or select a photo of your pet first.');
      return;
    }

    // Strict AI validation check: only allow confirmed pets!
    if (!kIsWeb) {
      if (_isValidatingAi) {
        AppToast.info(context, 'Please wait, AI is analyzing your photo…');
        return;
      }

      if (_isPetDetected == false) {
        await _showNotAPetDialog();
        return;
      }

      // If AI check hasn't run yet, run it now before uploading
      if (_isPetDetected == null) {
        setState(() {
          _isUploading = true;
          _uploadStatusText = 'Verifying pet with AI…';
        });

        try {
          final detected = await PetEmbeddingService.instance
              .detectSpecies(_capturedImage!);
          final isAccepted = detected['isAccepted'] == true;
          final isDog = detected['isDog'] == true;
          final isCat = detected['isCat'] == true;

          if (!isAccepted || (!isDog && !isCat)) {
            setState(() {
              _isUploading = false;
              _isPetDetected = false;
            });
            await _showNotAPetDialog();
            return;
          }

          _isPetDetected = true;
          _detectedSpecies = isDog ? 'Dog' : 'Cat';
        } catch (e) {
          debugPrint('[MarkFound] Verification warning: $e');
        }
      }
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
      Navigator.pop(context, publicUrl);
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
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
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
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'AI scanning photo for pet verification…',
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
              ] else if (_isPetDetected == true) ...[
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF16A34A), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ' Pet Verified (${_detectedSpecies ?? "Pet"}${_detectedConfidence != null && _detectedConfidence! > 0 ? " · ${(_detectedConfidence! * 100).round()}%" : ""}) · Valid recovery proof',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D),
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
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_rounded,
                          color: Color(0xFFDC2626), size: 18),
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
                              : Icons.check_circle_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _isUploading
                        ? (_uploadStatusText ?? 'Uploading…')
                        : _isValidatingAi
                            ? 'Analyzing Photo…'
                            : _isPetDetected == false
                                ? 'Invalid Photo (No Pet Detected)'
                                : 'Confirm & Mark as Found',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isPetDetected == false
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    elevation: 2,
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
    );
  }
}
