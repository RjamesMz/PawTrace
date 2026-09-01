import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_colors.dart';
import '../../core/navigation_helpers.dart';
import '../../widgets/bottom_nav_bar.dart';

/// Locate My Pet screen – live GPS tracking with map and pet info bottom sheet.
///
/// Features: full-screen map placeholder with satellite imagery, floating
/// map controls, pulsing pet marker, and a draggable bottom info panel.
class LocateMyPetScreen extends StatefulWidget {
  const LocateMyPetScreen({super.key});

  @override
  State<LocateMyPetScreen> createState() => _LocateMyPetScreenState();
}

class _LocateMyPetScreenState extends State<LocateMyPetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map (60% height)
          Positioned.fill(
            child: Column(
              children: [
                Expanded(flex: 60, child: _buildMap(context)),
                Expanded(flex: 40, child: const SizedBox()),
              ],
            ),
          ),
          // Map section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.58,
            child: _buildMap(context),
          ),
          // Bottom info card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomCard(),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildMap(BuildContext context) {
    return Stack(
      children: [
        // Satellite map background
        Positioned.fill(
          child: Image.network(
            'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=1200',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF8EB3A7),
              child: Center(
                  child: Icon(Icons.map,
                      size: 80, color: Colors.white.withOpacity(0.4))),
            ),
          ),
        ),
        // Gradient fade at edges
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withOpacity(0.3)
                  ]),
            ),
          ),
        ),
        // Controls overlay
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                _mapBtn(Icons.arrow_back, () => handleSafeBack(context)),
                // Live tracking badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(999)),
                  child: Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Live Tracking Active',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF15803D))),
                  ]),
                ),
                // Layer + locate buttons
                Column(children: [
                  _mapBtn(Icons.layers, () {}),
                  const SizedBox(height: 8),
                  _mapBtn(Icons.my_location, () {}, color: AppColors.primary),
                ]),
              ],
            ),
          ),
        ),
        // Paw marker in center
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) =>
                    Stack(alignment: Alignment.center, children: [
                  Transform.scale(
                    scale: _pulseAnim.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primaryContainer.withOpacity(0.3),
                            width: 1.5),
                      ),
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primaryContainer.withOpacity(0.4),
                            blurRadius: 16)
                      ],
                    ),
                    child:
                        const Icon(Icons.pets, color: Colors.white, size: 28),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
          ],
        ),
        child: Icon(icon, color: color ?? AppColors.onSurface, size: 22),
      ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 40,
              offset: const Offset(0, -10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: AppColors.outlineVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          // Pet header
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.primaryContainer, width: 2),
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://images.unsplash.com/photo-1587300003388-59208cc962cb?w=200',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Icon(Icons.pets,
                            color: AppColors.primaryContainer)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cooper',
                          style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface)),
                      Row(children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Active',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF15803D))),
                      ]),
                    ]),
              ),
              IconButton(
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.onSurfaceVariant),
                  onPressed: () {}),
            ],
          ),
          const SizedBox(height: 14),
          // Status pills
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(Icons.location_on, 'Virac', AppColors.surfaceContainerLow),
            _pill(Icons.schedule, '30s ago', AppColors.surfaceContainerLow),
            _pill(Icons.battery_5_bar, '85%', const Color(0xFFF0FDF4),
                iconColor: const Color(0xFF22C55E),
                textColor: const Color(0xFF15803D)),
          ]),
          const SizedBox(height: 14),
          // Location details
          Text('LOCATION DETAILS',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.onSurfaceVariant.withOpacity(0.7))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.2))),
            child: Column(children: [
              _locationRow(Icons.explore, 'Lat: 13.9747, Lon: 124.2432'),
              const SizedBox(height: 8),
              _locationRow(Icons.home,
                  'Brgy. Santa Ana, Calatagan, Batangas, Philippines'),
            ]),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.warning_amber_rounded, size: 20),
                label: const Text('Report as Lost'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppColors.outlineVariant.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                minimumSize: const Size(52, 52),
              ),
              child: const Icon(Icons.share, color: AppColors.onSurface),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, Color bg,
      {Color? iconColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: iconColor ?? AppColors.primary),
        const SizedBox(width: 4),
        Text(text,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor ?? AppColors.onSurfaceVariant)),
      ]),
    );
  }

  Widget _locationRow(IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: AppColors.primary, size: 18),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface))),
    ]);
  }
}
