import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import '../../widgets/notification_bell_button.dart';
import '../shared/news_detail_screen.dart';

/// Dashboard Home screen – news-first landing page with a quick view of
/// the most recent lost-pet reports.
class DashboardHomeScreen extends StatefulWidget {
  const DashboardHomeScreen({super.key});

  @override
  State<DashboardHomeScreen> createState() => _DashboardHomeScreenState();
}

class _DashboardHomeScreenState extends State<DashboardHomeScreen> {
  String _userName = '';
  String? _photoUrl;
  List<Map<String, dynamic>> _newsList = [];
  List<Map<String, dynamic>> _lostPetsList = [];
  bool _isLoadingNews = true;
  bool _isLoadingLostPets = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchNews();
    _fetchLostPets();
  }

  Future<void> _loadProfile() async {
    final profile = await AuthService.instance.getCurrentUserProfile();
    if (profile != null && mounted) {
      setState(() {
        final fName = profile['first_name'] as String? ?? '';
        final mName = profile['middle_name'] as String? ?? '';
        final sName = profile['surname'] as String? ?? '';
        final suffix = profile['suffix'] as String? ?? '';
        _userName =
            [fName, mName, sName, suffix].where((s) => s.isNotEmpty).join(' ');
        _photoUrl = profile['photo_url'];
      });
      final userBarangay = profile['barangay'] as String? ?? '';
      if (userBarangay.isNotEmpty) {
        _fetchNews(barangay: userBarangay);
      }
    }
  }

  Future<void> _fetchNews({String? barangay}) async {
    try {
      var query = Supabase.instance.client.from('news').select();
      if (barangay != null && barangay.isNotEmpty) {
        query = query.eq('barangay', barangay);
      }
      final data = await query.order('created_at', ascending: false).limit(5);
      if (mounted) {
        setState(() {
          _newsList = List<Map<String, dynamic>>.from(data);
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
      if (mounted) {
        setState(() => _isLoadingNews = false);
      }
    }
  }

  Future<void> _fetchLostPets() async {
    try {
      final data = await Supabase.instance.client
          .from('lost_reports')
          .select('*, pets(*), owner_id(*)')
          .eq('status', 'active')
          .order('reported_at', ascending: false)
          .limit(5);
      if (mounted) {
        setState(() {
          _lostPetsList = List<Map<String, dynamic>>.from(data);
          _isLoadingLostPets = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lost reports: $e');
      if (mounted) {
        setState(() => _isLoadingLostPets = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get first name for greeting
    final firstName = _userName.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              photoUrl: _photoUrl,
              onSettings: () =>
                  Navigator.pushNamed(context, AppRoutes.settings),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroCard(userName: firstName),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: 'Latest news',
                    subtitle: 'Fresh updates from the community and field team',
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: _isLoadingNews
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _newsList.isEmpty
                      ? Center(
                          child: Text(
                            'No news updates found.',
                            style: GoogleFonts.inter(
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.5)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          scrollDirection: Axis.horizontal,
                          itemCount: _newsList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) =>
                              _NewsCard(item: _newsList[index]),
                        ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: _SectionHeader(
                title: 'Current lost pets',
                subtitle: 'The latest active reports available right now',
              ),
            ),
          ),
          _isLoadingLostPets
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  ),
                )
              : _lostPetsList.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 20),
                        child: Center(
                          child: Text(
                            'No active lost pet reports.',
                            style: GoogleFonts.inter(
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.5)),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final pet = _lostPetsList[index];
                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              0,
                              20,
                              index == _lostPetsList.length - 1 ? 120 : 16,
                            ),
                            child: _LostPetPreviewCard(
                              pet: pet,
                              onTap: () => Navigator.pushNamed(
                                  context, AppRoutes.lostPetDetails),
                            ),
                          );
                        },
                        childCount: _lostPetsList.length,
                      ),
                    ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  final String? photoUrl;

  const _TopBar({required this.onSettings, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, color: AppColors.primary, size: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'PawTrace',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                icon: const Icon(Icons.search,
                    color: AppColors.onSurfaceVariant, size: 20),
              ),
              const NotificationBellButton(size: 20),
              IconButton(
                tooltip: 'My Registered Pets',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                icon: const Icon(Icons.pets_rounded,
                    color: AppColors.primary, size: 20),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.myPets);
                },
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 36, height: 36),
                onPressed: onSettings,
                icon: ClipOval(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: photoUrl != null && photoUrl!.isNotEmpty
                        ? Image.network(
                            photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceContainerHighest,
                              child: const Icon(Icons.person,
                                  size: 16, color: AppColors.onSurfaceVariant),
                            ),
                          )
                        : Container(
                            color: AppColors.surfaceContainerHighest,
                            child: const Icon(Icons.person,
                                size: 16, color: AppColors.onSurfaceVariant),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String userName;
  const _HeroCard({required this.userName});

  @override
  Widget build(BuildContext context) {
    final greeting =
        userName.isNotEmpty ? 'Welcome back, $userName' : 'Welcome back';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryContainer.withOpacity(0.92)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting,
              style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            'Today\'s dashboard surfaces the latest pet news and active lost reports first.',
            style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4)),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final category = item['category'] as String? ?? 'Announcement';
    final title = item['title'] as String? ?? '';
    final imageUrl = item['image_url'] as String? ?? '';
    final source = item['source'] as String? ?? 'PawTrace';
    final summary = item['summary'] as String? ?? '';
    final timeAgo = _formatTimeAgo(item['created_at']);
    final accentColor = _parseHexColor(item['accent_color']);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(news: item),
          ),
        );
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 8))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: accentColor.withOpacity(0.15)),
                      )
                    : Container(color: accentColor.withOpacity(0.15)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.72)
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(category.toUpperCase(),
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$source · $timeAgo',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                Text(summary,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.onSurfaceVariant),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _LostPetPreviewCard extends StatelessWidget {
  final Map<String, dynamic> pet;
  final VoidCallback onTap;

  const _LostPetPreviewCard({required this.pet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final petData = pet['pets'] as Map<String, dynamic>?;
    // 'owner_id' is the FK-hint alias used in the select query
    final userData = (pet['owner_id'] is Map<String, dynamic>
            ? pet['owner_id'] as Map<String, dynamic>
            : null) ??
        (pet['users'] as Map<String, dynamic>?);

    final petName = petData?['name'] as String? ?? 'Unknown';
    final breed = petData?['breed'] as String? ?? 'Unknown Breed';
    final imageUrl =
        pet['photo_url'] as String? ?? petData?['photo_url'] as String? ?? '';
    final location = pet['last_seen_address'] as String? ??
        pet['barangay'] as String? ??
        'Calatagan';
    final timeAgo = _formatTimeAgo(pet['created_at']);

    final ownerName = userData != null
        ? [
            userData['first_name'],
            userData['middle_name'],
            userData['surname'],
            userData['suffix']
          ].where((s) => s != null && s.toString().isNotEmpty).join(' ')
        : 'Unknown Owner';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.18)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 92,
                height: 92,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceContainerHigh,
                          child: const Icon(Icons.pets,
                              color: AppColors.primaryContainer, size: 34),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Icon(Icons.pets,
                            color: AppColors.primaryContainer, size: 34),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(petName,
                            style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 12),
                      Text('LOST',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.primaryContainer)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(breed,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(location,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('$timeAgo · $ownerName',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Helper Functions ──────────────────────────────────────────────────

Color _parseHexColor(String? hexString) {
  if (hexString == null || hexString.isEmpty) return AppColors.primary;
  try {
    final hex = hexString.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
  } catch (_) {}
  return AppColors.primary;
}

String _formatTimeAgo(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) return 'Recent';
  try {
    final dt = DateTime.parse(timestamp);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  } catch (_) {
    return 'Recent';
  }
}
