import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../shared/news_detail_screen.dart';

/// Barangay Admin Home Screen — main dashboard visible when the admin taps Home.
///
/// Shows greeting, 4 stat cards, pending verification reports, AI match preview,
/// and recent activity. All data scoped by the admin's assigned barangay.
class BarangayAdminHomeScreen extends StatefulWidget {
  const BarangayAdminHomeScreen({super.key});

  @override
  State<BarangayAdminHomeScreen> createState() =>
      _BarangayAdminHomeScreenState();
}

class _BarangayAdminHomeScreenState extends State<BarangayAdminHomeScreen> {
  final _supabase = Supabase.instance.client;

  String _adminBarangay = '';
  String _adminName = 'Admin';
  bool _isLoading = true;

  // Stat counts
  int _registeredPets = 0;
  int _lostReports = 0;
  int _registeredUsers = 0;

  // Data lists
  List<Map<String, dynamic>> _news = [];
  List<Map<String, dynamic>> _recentActivity = [];
  bool _newsExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    // Fetch admin barangay and profile
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    final profile = await AuthService.instance.getCurrentUserProfile();
    if (profile != null) {
      final first = profile['first_name'] ?? '';
      final surname = profile['surname'] ?? '';
      if (first.toString().isNotEmpty) {
        _adminName = '$first $surname'.trim();
      }
    }

    await Future.wait([
      _fetchStats(),
      _fetchNews(),
      _fetchRecentActivity(),
    ]);

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchStats() async {
    try {
      // Registered pets
      final pets = await _supabase
          .from('pets')
          .select('id')
          .eq('barangay', _adminBarangay);
      _registeredPets = pets.length;

      // Lost reports
      final lost = await _supabase
          .from('lost_reports')
          .select('id')
          .eq('barangay', _adminBarangay);
      _lostReports = lost.length;

      // Registered Users count (scoped to barangay)
      final users = await _supabase
          .from('users')
          .select('user_id')
          .eq('barangay', _adminBarangay);
      _registeredUsers = users.length;
    } catch (e) {
      debugPrint('Error fetching stats: $e');
    }
  }

  Future<void> _fetchNews() async {
    try {
      final data = await _supabase
          .from('news')
          .select()
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false)
          .limit(3);
      _news = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Error fetching news: $e');
    }
  }

  Future<void> _fetchRecentActivity() async {
    try {
      // Fetch recently registered pets as activity items
      final pets = await _supabase
          .from('pets')
          .select('name, created_at, users(first_name, surname)')
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false)
          .limit(5);

      final List<Map<String, dynamic>> activities = [];
      for (final p in pets) {
        final petName = p['name'] ?? 'A pet';
        final u = p['users'];
        final ownerName = u != null
            ? '${u['first_name'] ?? ''} ${u['surname'] ?? ''}'.trim()
            : 'Someone';
        activities.add({
          'description': '$petName was registered by $ownerName',
          'timestamp': p['created_at'],
          'color': const Color(0xFF22C55E),
        });
      }

      // Fetch recent lost reports as activity
      final reports = await _supabase
          .from('lost_reports')
          .select('*, pets(name), owner_id(first_name, surname)')
          .eq('barangay', _adminBarangay)
          .order('reported_at', ascending: false)
          .limit(5);

      for (final r in reports) {
        final petData = r['pets'];
        final petName = petData is Map ? (petData['name'] ?? 'A pet') : 'A pet';
        final userData = r['owner_id'];
        final reporterName = userData is Map
            ? '${userData['first_name'] ?? ''} ${userData['surname'] ?? ''}'
                .trim()
            : 'Someone';
        activities.add({
          'description': '$petName was reported lost by $reporterName',
          'timestamp': r['reported_at'],
          'color': AppColors.error,
        });
      }

      // Sort by timestamp descending
      activities.sort((a, b) {
        final ta = a['timestamp']?.toString() ?? '';
        final tb = b['timestamp']?.toString() ?? '';
        return tb.compareTo(ta);
      });

      _recentActivity = activities.take(8).toList();
    } catch (e) {
      debugPrint('Error fetching activity: $e');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGreeting(),
                          const SizedBox(height: 18),
                          _buildStatCards(),
                          const SizedBox(height: 24),
                          _buildNewsSection(),
                          const SizedBox(height: 24),
                          _buildRecentActivity(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
          const BottomNavBar(currentIndex: 0),
        ],
      ),
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding:
          EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // PawTrace logo + name
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'PawTrace',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          // Notification bell with red badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.onSurfaceVariant, size: 26),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Admin avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Greeting ────────────────────────────────────────────────────────────────

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_greeting()}, $_adminName',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Here\'s what\'s happening in Brgy. $_adminBarangay today.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stat Cards ──────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final stats = [
      _StatData(
          'Registered\nPets', _registeredPets, Icons.pets, AppColors.primary),
      _StatData('Lost\nReports', _lostReports, Icons.warning_amber_rounded,
          AppColors.error),
      _StatData('Registered\nUsers', _registeredUsers, Icons.group_rounded,
          const Color(0xFF9333EA)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: stats
            .map((s) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _buildStatCard(s),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildStatCard(_StatData stat) {
    return Container(
      width: 130,
      height: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stat.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: stat.color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stat.count}',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Icon(stat.icon, color: Colors.white.withOpacity(0.85), size: 22),
            ],
          ),
          Text(
            stat.label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.9),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── News Announcements Section ─────────────────────────────────────────────

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        content: Text('This will permanently remove the news post.',
            style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _supabase.from('news').delete().eq('id', postId);
      _fetchNews();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting post: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Widget _buildNewsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'News & Announcements',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, AppRoutes.postNews);
                  _fetchNews();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Create Post',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryContainer.withOpacity(0.3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _newsExpanded = !_newsExpanded),
                child: AnimatedRotation(
                  turns: _newsExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          firstChild: _news.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.campaign_outlined,
                            size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('No announcements yet',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.6))),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: _news
                      .map((post) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: _buildPostCard(post),
                          ))
                      .toList(),
                ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _newsExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final title = post['title'] as String? ?? 'Untitled';
    final summary = post['summary'] as String? ?? '';
    final category = post['category'] as String? ?? '';
    final imageUrl = post['image_url'] as String? ?? '';
    final accentHex = post['accent_color'] as String? ?? '#FF6600';
    final postId = post['id']?.toString() ?? '';

    Color accentColor = AppColors.primary;
    try {
      final hex = accentHex.replaceFirst('#', '');
      accentColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NewsDetailScreen(news: post),
                  ),
                );
              },
              child: Row(
                children: [
                  if (imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14)),
                      child: Image.network(
                        imageUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            width: 72,
                            height: 72,
                            color: accentColor.withOpacity(0.15),
                            child: Icon(Icons.article_rounded,
                                color: accentColor, size: 28)),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            bottomLeft: Radius.circular(14)),
                      ),
                      child: Icon(Icons.article_rounded, color: accentColor, size: 28),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(category,
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: accentColor)),
                            ),
                          Text(title,
                              style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (summary.isNotEmpty)
                            Text(summary,
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: AppColors.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            tooltip: 'Delete post',
            onPressed: () => _deletePost(postId),
          ),
        ],
      ),
    );
  }

  // ─── Recent Activity ─────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recent Activity',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_recentActivity.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text('No recent activity',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withOpacity(0.6))),
              ),
            ),
          )
        else
          ...List.generate(
            _recentActivity.length,
            (i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _buildActivityItem(_recentActivity[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final description = activity['description'] as String? ?? '';
    final color = activity['color'] as Color? ?? AppColors.primary;
    final timeAgo = _formatTimeAgo(activity['timestamp']?.toString());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style:
                  GoogleFonts.inter(fontSize: 13, color: AppColors.onSurface),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            timeAgo,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

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
}

class _StatData {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.count, this.icon, this.color);
}
