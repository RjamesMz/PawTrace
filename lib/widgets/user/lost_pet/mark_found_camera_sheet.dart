import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';

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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked != null) {
        setState(() {
          _capturedImage = File(picked.path);
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not access camera/gallery: $e');
      }
    }
  }

  Future<void> _confirmAndUpload() async {
    if (_capturedImage == null) {
      AppToast.error(context, 'Please capture or select a photo of your pet first.');
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
      final fileName = 'found_reports/found_${widget.reportId}_${timestamp}_$randomSuffix.$cleanExt';

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
                  onPressed: _isUploading ? null : _confirmAndUpload,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded, size: 20),
                  label: Text(
                    _isUploading
                        ? (_uploadStatusText ?? 'Uploading…')
                        : 'Confirm & Mark as Found',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
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
