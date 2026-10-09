import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_toast.dart';
import '../../../services/ai/pet_embedding_service.dart';
import '../../../services/ai/pet_match_service.dart';
import '../../../widgets/user/ai_scan/ai_scan_widgets.dart';

export '../../../widgets/user/ai_scan/ai_scan_widgets.dart';

/// AI Scan screen – live camera view for direct pet scanning and visual matches.
class AiScanScreen extends StatefulWidget {
  const AiScanScreen({super.key});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseCtrl;

  // Live Camera state (Back camera only)
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraPermissionDenied = false;
  bool _isCapturing = false;
  bool _isTorchOn = false;
  bool _isSwitchingToLive = false;

  File? _pickedImage;
  bool _scanning = false;
  bool _done = false;
  List<PetMatchResult> _results = [];
  Map<String, dynamic>? _speciesResult;
  String? _error;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _disposeCamera();
    super.dispose();
  }

  bool _isConfiguringCamera = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _cameraController;
    if (cameraController == null) return;

    bool isReady = false;
    try {
      isReady = cameraController.value.isInitialized;
    } catch (_) {
      isReady = false;
    }
    if (!isReady) return;

    if (state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed && _pickedImage == null) {
      _setupBackCamera();
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _isCameraInitialized = false;
    if (mounted) setState(() {});
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _isCameraInitialized = false);
        return;
      }
      _cameras = cameras;
      await _setupBackCamera();
    } on CameraException catch (e) {
      debugPrint('CameraException on init: ${e.code} - ${e.description}');
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        if (e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt' ||
            e.code == 'cameraPermission') {
          _isCameraPermissionDenied = true;
        }
      });
    } catch (e) {
      debugPrint('Error finding cameras: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  Future<void> _setupBackCamera() async {
    if (_isConfiguringCamera) return;
    _isConfiguringCamera = true;

    // Safely dispose old controller first while removing preview from tree
    final oldController = _cameraController;
    _cameraController = null;
    if (mounted) setState(() => _isCameraInitialized = false);
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (_) {}
      // Brief pause to allow Android camera HAL / CameraX native thread
      // to cleanly unbind prior surfaces before requesting new hardware bindings
      await Future.delayed(const Duration(milliseconds: 150));
    }

    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isCameraInitialized = false);
        return;
      }

      // Strictly select the BACK camera
      final backCamera = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      // Do NOT set imageFormatGroup: ImageFormatGroup.jpeg because CameraX
      // binds an unnecessary YUV ImageAnalysis surface that exceeds hardware limits
      // ("No supported surface combination is found for camera device").
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _cameraController = controller;
      setState(() {
        _isCameraInitialized = true;
        _isCameraPermissionDenied = false;
        _isTorchOn = false;
      });
    } on CameraException catch (e) {
      debugPrint('CameraException on back camera setup: ${e.code}');
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        if (e.code == 'CameraAccessDenied' ||
            e.code == 'CameraAccessDeniedWithoutPrompt' ||
            e.code == 'cameraPermission') {
          _isCameraPermissionDenied = true;
        }
      });
    } catch (e) {
      debugPrint('Unexpected error setting up camera: $e');
      if (mounted) setState(() => _isCameraInitialized = false);
    } finally {
      _isConfiguringCamera = false;
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _cameraController;
    if (controller == null) return;
    try {
      if (!controller.value.isInitialized) return;
      if (_isTorchOn) {
        await controller.setFlashMode(FlashMode.off);
        if (mounted) setState(() => _isTorchOn = false);
      } else {
        await controller.setFlashMode(FlashMode.torch);
        if (mounted) setState(() => _isTorchOn = true);
      }
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _cameraController;
    bool isReady = false;
    try {
      isReady = controller != null && controller.value.isInitialized;
    } catch (_) {
      isReady = false;
    }

    if (!isReady || controller == null) {
      AppToast.error(context, 'Camera is not ready yet. Please wait a moment.');
      return;
    }
    if (controller.value.isTakingPicture || _scanning || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      HapticFeedback.mediumImpact();
      final XFile photo = await controller.takePicture();

      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _pickedImage = File(photo.path);
        _done = false;
        _results = [];
        _speciesResult = null;
        _error = null;
      });
      await _runScan();
    } catch (e) {
      if (mounted) setState(() => _isCapturing = false);
      if (mounted) {
        AppToast.error(context, 'Failed to capture photo: $e');
      }
    }
  }

  Future<void> _returnToLiveCamera() async {
    if (_isSwitchingToLive) return;
    setState(() => _isSwitchingToLive = true);

    try {
      // The live camera view remains continuously mounted at the base of the Stack,
      // so we simply unhide it by clearing _pickedImage.
      final controller = _cameraController;
      bool isReady = false;
      if (controller != null) {
        try {
          isReady = controller.value.isInitialized;
        } catch (_) {
          isReady = false;
        }
      }

      if (!isReady) {
        await _setupBackCamera();
      }
    } catch (e) {
      debugPrint('Error returning to live camera: $e');
    } finally {
      if (mounted) {
        setState(() {
          _pickedImage = null;
          _done = false;
          _results = [];
          _speciesResult = null;
          _error = null;
          _scanning = false;
          _isSwitchingToLive = false;
        });
      }
    }
  }

  Future<void> _pickGalleryImage() async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      setState(() {
        _pickedImage = File(picked.path);
        _done = false;
        _results = [];
        _speciesResult = null;
        _error = null;
      });
      await _runScan();
    } on PlatformException catch (_) {
      if (!mounted) return;
      AppToast.error(
          context, 'Gallery access denied. Please allow photo permissions.');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to select image: $e');
    }
  }

  Future<void> _runScan() async {
    if (_pickedImage == null) return;
    setState(() {
      _scanning = true;
      _error = null;
      _speciesResult = null;
      _results = [];
    });
    try {
      final detected =
          await PetEmbeddingService.instance.detectSpecies(_pickedImage!);
      _speciesResult = detected;

      if (detected['isAccepted'] != true) {
        if (mounted) {
          setState(() {
            _scanning = false;
            _done = false;
            _results = [];
          });
          await _showNotRecognizedDialog();
        }
        return;
      }

      final embedding =
          await PetEmbeddingService.instance.extractEmbedding(_pickedImage!);
      if (embedding == null) {
        if (mounted) {
          setState(() {
            _error =
                'Scan failed: Unable to extract pet features from this photo.';
            _scanning = false;
            _done = true;
          });
        }
        return;
      }

      final isDog = detected['isDog'] == true;
      final matches =
          await PetMatchService.instance.findMatches(embedding, isDog: isDog);
      if (mounted) {
        setState(() {
          _results = matches;
          _scanning = false;
          _done = true;
        });
      }
    } on PawTraceServerException catch (e) {
      // AI server is down — show a dedicated maintenance dialog.
      if (mounted) {
        setState(() {
          _scanning = false;
          _done = false;
        });
        await _showServerMaintenanceDialog(
          detail: e.message,
          onRetry: () => _runScan(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Scan failed: $e';
          _scanning = false;
          _done = true;
        });
      }
    }
  }

  /// Shows a bottom dialog explaining that the AI server is under maintenance.
  Future<void> _showServerMaintenanceDialog(
      {String? detail, VoidCallback? onRetry}) async {
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
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE0B2), Color(0xFFFFA726)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFA726).withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.build_circle_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Server Under Maintenance',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'The PetTrace AI scanning service is currently unavailable. Please try again later.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Info banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFE65100),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Manual search via Lost Pets tab is still available.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFBF360C),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Retry button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // Clear cached URL so the latest ngrok URL is re-fetched
                    // from Supabase before retrying.
                    PetEmbeddingService.instance.clearUrlCache();
                    onRetry?.call();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  label: Text(
                    'Retry Now',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF57C00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    shadowColor: const Color(0xFFF57C00).withOpacity(0.35),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Dismiss button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Dismiss',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
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

  Future<void> _showNotRecognizedDialog() async {
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
              // Glowing Icon Header
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.pets_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Pet Not Recognized',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'PetTrace AI only supports Dogs and Cats (including local Aspin and Puspin breeds).',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),

              // Supported Category Badges
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFB74D).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🐶', style: TextStyle(fontSize: 17)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Dogs',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE65100),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFCE93D8).withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🐱', style: TextStyle(fontSize: 17)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Cats',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF7B1FA2),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tips Card
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 17,
                          color: Color(0xFFF57C00),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tips for best recognition:',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTipItem('Ensure good lighting on the pet\'s face'),
                    const SizedBox(height: 4),
                    _buildTipItem('Keep the pet centered and close in frame'),
                    const SizedBox(height: 4),
                    _buildTipItem('Avoid blurry, dark, or obstructed shots'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  label: Text(
                    'Try Another Photo',
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
                    elevation: 3,
                    shadowColor: AppColors.primary.withOpacity(0.35),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3, right: 6),
          child: Icon(Icons.check_circle, size: 13, color: Color(0xFF4CAF50)),
        ),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppColors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ),
      ],
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildViewfinder(),
                  const SizedBox(height: 20),
                  _buildActionControls(),
                  if (_scanning) ...[
                    const SizedBox(height: 24),
                    _buildScanningIndicator(),
                  ],
                  if (_done) ...[
                    const SizedBox(height: 24),
                    _buildResults(),
                  ],
                ],
              ),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          Text(
            'Scan Close Match',
            style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.help_outline),
            color: AppColors.onSurfaceVariant,
            onPressed: () => AiScanHelpSheet.show(context),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    return Container(
      height: 330,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Keep live camera continuously mounted at the base of the Stack so its
          // native preview surface is NEVER destroyed, unmounted, or rebound when taking consecutive shots.
          _buildLiveCameraView(),

          // Overlay captured / selected photo on top
          if (_pickedImage != null) _buildCapturedPhotoOverlay(),
        ],
      ),
    );
  }

  Widget _buildCapturedPhotoOverlay() {
    if (_pickedImage == null) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_pickedImage!, fit: BoxFit.cover),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: Colors.black.withOpacity(0.35)),
        ),
        Center(
          child: Image.file(_pickedImage!, fit: BoxFit.contain),
        ),
        // Corner brackets overlay
        Positioned.fill(child: _buildCorners()),
        if (_scanning)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                color: AppColors.primaryContainer
                    .withOpacity(0.08 + _pulseCtrl.value * 0.08),
              ),
            ),
          ),
        // Top-right Live Camera button to return to live feed
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _isSwitchingToLive ? null : _returnToLiveCamera,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSwitchingToLive)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(
                      _isSwitchingToLive ? 'Starting…' : 'Live Camera',
                      style: GoogleFonts.inter(
                        fontSize: 11,
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
    );
  }

  Widget _buildLiveCameraView() {
    if (_isCameraPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_rounded,
                  size: 48, color: Colors.white.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(
                'Camera Access Required',
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please allow camera permissions in device settings to use live pet scanning.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _initCamera,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraController;
    bool isControllerReady = false;
    if (_isCameraInitialized && controller != null) {
      try {
        isControllerReady = controller.value.isInitialized;
      } catch (_) {
        isControllerReady = false;
      }
    }

    if (!isControllerReady || controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 14),
            Text(
              'Starting live camera…',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double cameraRatio = 3.0 / 4.0;
        try {
          final ratio = controller.value.aspectRatio;
          cameraRatio = ratio > 1.0 ? 1.0 / ratio : ratio;
        } catch (_) {}

        return Stack(
          fit: StackFit.expand,
          children: [
            // Live Camera Preview fitted smoothly
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth / cameraRatio,
                child: CameraPreview(controller),
              ),
            ),

            // Corner brackets overlay
            Positioned.fill(child: _buildCorners()),

            // Shutter flash or capturing pulse
            if (_isCapturing || _scanning)
              Positioned.fill(
                child: Container(
                  color: _isCapturing
                      ? Colors.white.withOpacity(0.5)
                      : AppColors.primary.withOpacity(0.12),
                ),
              ),

            // Top Badges & Controls Overlay
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  // Live Camera Indicator Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LIVE CAM',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Torch Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: _isTorchOn
                            ? const Color(0xFFFFB300)
                            : Colors.white,
                        size: 18,
                      ),
                      tooltip: 'Toggle Flash',
                      onPressed: _toggleTorch,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCorners() {
    return const CustomPaint(painter: CornerPainter());
  }

  Widget _buildActionControls() {
    if (_pickedImage != null) {
      // Photo is captured or selected
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_scanning || _isSwitchingToLive)
                        ? null
                        : _returnToLiveCamera,
                    icon: _isSwitchingToLive
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.videocam_rounded, size: 20),
                    label: Text(
                      _isSwitchingToLive ? 'Starting Camera…' : 'Live Camera',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _scanning ? null : _pickGalleryImage,
                    icon: const Icon(Icons.photo_library_rounded, size: 19),
                    label: Text(
                      'Gallery',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      side: BorderSide(
                          color: AppColors.outlineVariant.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!_scanning && !_done) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _runScan,
                icon: const Icon(Icons.search_rounded),
                label: Text(
                  'Find Matches',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Live Camera mode: Capture & Scan directly!
    return Column(
      children: [
        // Main Capture & Scan Button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: (_scanning || _isCapturing) ? null : _captureAndScan,
            icon: const Icon(Icons.camera_alt_rounded, size: 22),
            label: Text(
              _isCapturing ? 'Capturing photo…' : 'Capture & Scan Pet',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.35),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary option: Gallery
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: (_scanning || _isCapturing) ? null : _pickGalleryImage,
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: Text(
              'Upload from Gallery',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side:
                  BorderSide(color: AppColors.outlineVariant.withOpacity(0.35)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryContainer.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 14),
          Text('Analyzing pet photo…',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('Running AI matching',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Failed',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(
                color: AppColors.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceContainerHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets_rounded,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No matching lost pets found',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_speciesResult != null && _speciesResult!['isAccepted'] == true)
          ...[],
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${_results.length} Active Lost Pet Match${_results.length == 1 ? "" : "es"} Found',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        ..._results.map((r) => AiMatchCard(result: r)),
      ],
    );
  }

}
