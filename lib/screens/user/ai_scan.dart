import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../services/pet_embedding_service.dart';
import '../../services/pet_match_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// AI Scan screen – pick or photograph a pet and find visual matches.
class AiScanScreen extends StatefulWidget {
  const AiScanScreen({super.key});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

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
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      setState(() {
        _pickedImage = File(picked.path);
        _done = false;
        _results = [];
        _speciesResult = null;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      final message = source == ImageSource.camera
          ? 'Camera is unavailable or permission was denied. Please allow camera access in device settings and try again.'
          : 'Photo access was denied. Please allow gallery access in device settings and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$message (${e.code})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open image source: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
                'PawTrace AI only supports Dogs and Cats (including local Aspin and Puspin breeds).',
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
                  _buildSourceButtons(),
                  const SizedBox(height: 20),
                  if (_pickedImage != null) _buildScanButton(),
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
          const BottomNavBar(currentIndex: 2),
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
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primaryContainer.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20)
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _pickedImage != null
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_pickedImage!, fit: BoxFit.cover),
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
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets,
                    size: 64, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text(
                  'No photo selected',
                  style: GoogleFonts.inter(
                      fontSize: 15, color: Colors.white.withOpacity(0.5)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Use the buttons below to pick a photo.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: Colors.white.withOpacity(0.35)),
                ),
              ],
            ),
    );
  }

  Widget _buildCorners() {
    return CustomPaint(painter: _CornerPainter());
  }

  Widget _buildSourceButtons() {
    return Row(
      children: [
        Expanded(
          child: _SourceButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () => _pickImage(ImageSource.gallery),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SourceButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () => _pickImage(ImageSource.camera),
          ),
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _scanning ? null : _runScan,
            icon: const Icon(Icons.search_rounded),
            label: Text(
              'Find Matches',
              style: GoogleFonts.montserrat(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(height: 8),
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
          Text('Running on-device AI matching',
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
        ..._results.map((r) => _MatchCard(result: r)),
      ],
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How it works',
                  style: GoogleFonts.montserrat(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _helpRow(Icons.photo_library_rounded,
                  'Pick a clear photo of the pet you found (dog or cat only).'),
              _helpRow(Icons.memory_rounded,
                  'On-device AI verifies the species and analyzes visual features.'),
              _helpRow(Icons.search_rounded,
                  'Results are compared against registered pets in database.'),
              _helpRow(Icons.pets_rounded,
                  'Top matches are shown with a similarity score.'),
              const SizedBox(height: 8),
            ]),
      ),
    );
  }

  Widget _helpRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.onSurface))),
      ]),
    );
  }
}

// ─── Corner bracket overlay painter ───────────────────────────────────────────

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 28.0;
    const pad = 16.0;

    final corners = [
      // top-left
      const [Offset(pad, pad + len), Offset(pad, pad), Offset(pad + len, pad)],
      // top-right
      [
        Offset(size.width - pad - len, pad),
        Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + len)
      ],
      // bottom-left
      [
        Offset(pad, size.height - pad - len),
        Offset(pad, size.height - pad),
        Offset(pad + len, size.height - pad)
      ],
      // bottom-right
      [
        Offset(size.width - pad - len, size.height - pad),
        Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad, size.height - pad - len)
      ],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Source button widget ──────────────────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ─── Match result card ─────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final PetMatchResult result;
  const _MatchCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final photoUrl = result.photoUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.pushNamed(
              context,
              AppRoutes.lostPetDetails,
              arguments: {
                'report_id': result.reportId,
                'pet_id': result.petId,
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Lost pet photo on the left
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 76,
                        height: 76,
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _petPlaceholder(),
                              )
                            : _petPlaceholder(),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Pet details in center
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            result.breed.isNotEmpty
                                ? (result.barangay.isNotEmpty
                                    ? '${result.breed} · ${result.barangay}'
                                    : result.breed)
                                : (result.barangay.isNotEmpty
                                    ? result.barangay
                                    : result.species),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                size: 13,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Owner: ${result.ownerFullName}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Match badge on the right in orange
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFB74D).withOpacity(0.8),
                        ),
                      ),
                      child: Text(
                        '${result.percent}% Match',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.lostPetDetails,
                        arguments: {
                          'report_id': result.reportId,
                          'pet_id': result.petId,
                        },
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: Text(
                      'View Lost Report',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _petPlaceholder() {
    return Container(
      color: AppColors.surfaceContainerHigh,
      child: const Center(
        child: Icon(Icons.pets, size: 32, color: AppColors.outline),
      ),
    );
  }
}
