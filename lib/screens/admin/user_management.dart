import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/navigation_helpers.dart';
import '../../services/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// User Management screen – admin view of all registered users.
///
/// Features: search bar, filter pills (All/Pet Owners/Finders/Unverified),
/// user cards with avatar, role badge, verification dot, and Add User FAB.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  int _filterIndex = 0;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _news = [];
  bool _isLoading = true;
  bool _isLoadingNews = true;
  bool _newsExpanded = true;
  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.user;

  final List<String> _filters = ['All', 'Owners', 'Finders', 'Unverified'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    _currentUserRole = await AuthService.instance.getCurrentUserRole();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('users')
          .select()
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchNews() async {
    setState(() => _isLoadingNews = true);
    try {
      final data = await Supabase.instance.client
          .from('news')
          .select()
          .eq('barangay', _adminBarangay)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _news = List<Map<String, dynamic>>.from(data);
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
      if (mounted) setState(() => _isLoadingNews = false);
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post?', style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        content: Text('This will permanently remove the news post.', style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Supabase.instance.client.from('news').delete().eq('id', postId);
      _fetchNews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting post: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list = List.from(_users);
    if (_filterIndex == 1) {
      list = list.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'owner').toList();
    }
    if (_filterIndex == 2) {
      list = list.where((u) => (u['role'] ?? '').toString().toLowerCase() == 'finder').toList();
    }
    if (_filterIndex == 3) {
      list = list.where((u) => (u['phone'] ?? '').toString().isEmpty).toList();
    }
    final q = _searchCtrl.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((u) {
        final fName = (u['first_name'] ?? '').toString().toLowerCase();
        final sName = (u['surname'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return fName.contains(q) || sName.contains(q) || email.contains(q);
      }).toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: () async {
                      await _fetchUsers();
                    },
                    color: AppColors.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      children: [
                        // ── Users Section ──
                        _buildSectionHeader('Registered Users', Icons.group_rounded),
                        const SizedBox(height: 12),
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildFilterPills(),
                        const SizedBox(height: 12),
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No users found.',
                                style: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withOpacity(0.5)),
                              ),
                            ),
                          )
                        else
                          ..._filtered.map((u) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildUserCard(u),
                              )),
                      ],
                    ),
                  ),
          ),
          const BottomNavBar(currentIndex: 3),
        ],
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top, 16, 0),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(
        children: [
          Text('User Management', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
          const Spacer(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () async {
              final nav = Navigator.of(context);
              await AuthService.instance.signOut();
              nav.pushNamedAndRemoveUntil('/', (_) => false);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNewsSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'News Posts',
            style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface),
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.postNews);
            _fetchNews();
          },
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Create Post', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            backgroundColor: AppColors.primaryContainer.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() => _newsExpanded = !_newsExpanded),
          child: AnimatedRotation(
            turns: _newsExpanded ? 0 : -0.25,
            duration: const Duration(milliseconds: 250),
            child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsContent() {
    if (_isLoadingNews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_news.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.article_outlined, size: 40, color: AppColors.outlineVariant),
            const SizedBox(height: 10),
            Text('No posts yet.', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 4),
            Text('Tap "Create Post" to publish a news update.', style: GoogleFonts.inter(color: AppColors.onSurfaceVariant.withOpacity(0.4), fontSize: 12)),
          ],
        ),
      );
    }
    return Column(
      children: _news.map((post) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildPostCard(post),
      )).toList(),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
              child: Image.network(imageUrl, width: 72, height: 72, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: accentColor.withOpacity(0.15),
                  child: Icon(Icons.article_rounded, color: accentColor, size: 28)),
              ),
            )
          else
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(category, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: accentColor)),
                    ),
                  Text(title, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (summary.isNotEmpty)
                    Text(summary, style: GoogleFonts.inter(fontSize: 11, color: AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
            tooltip: 'Delete post',
            onPressed: () => _deletePost(postId),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.secondary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search, color: AppColors.outline),
        hintText: 'Search users by name or email...',
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant.withOpacity(0.5)),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildFilterPills() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final active = i == _filterIndex;
          return GestureDetector(
            onTap: () => setState(() => _filterIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primaryContainer : AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: active ? Colors.transparent : AppColors.outlineVariant.withOpacity(0.2)),
                boxShadow: active ? [BoxShadow(color: AppColors.primaryContainer.withOpacity(0.25), blurRadius: 8)] : [],
              ),
              child: Text(
                _filters[i],
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final fName = user['first_name'] as String? ?? '';
    final mName = user['middle_name'] as String? ?? '';
    final sName = user['surname'] as String? ?? '';
    final suffix = user['suffix'] as String? ?? '';
    final name = [fName, mName, sName, suffix].where((s) => s.isNotEmpty).join(' ');
    
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? 'owner';
    final photoUrl = user['photo_url'] as String? ?? '';
    final verified = (user['phone'] as String? ?? '').isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 46,
              height: 46,
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.secondaryContainer,
                        child: Center(child: Text(name.isNotEmpty ? name[0] : 'U', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.secondary))),
                      ),
                    )
                  : Container(
                      color: AppColors.secondaryContainer,
                      child: Center(child: Text(name.isNotEmpty ? name[0] : 'U', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.secondary))),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(name, style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 6),
                _roleBadge(role),
              ]),
              Text(email, style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: verified ? const Color(0xFF22C55E) : const Color(0xFFFBBF24),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  verified ? 'Verified' : 'Pending Verification',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: verified ? const Color(0xFF15803D) : const Color(0xFFD97706),
                  ),
                ),
              ]),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.outline, size: 20),
            onPressed: () => _showUserMenu(name, user),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final isAdmin = role.toLowerCase() == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.primaryFixed : AppColors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isAdmin ? const Color(0xFF6E3900) : AppColors.onSecondaryContainer,
        ),
      ),
    );
  }

  void _showUserMenu(String name, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.person_outline, color: AppColors.primary), title: Text('View Profile', style: GoogleFonts.inter(fontSize: 14)), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.verified_user, color: Color(0xFF22C55E)), title: Text('Verify User', style: GoogleFonts.inter(fontSize: 14)), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.error), title: Text('Remove User', style: GoogleFonts.inter(fontSize: 14, color: AppColors.error)), onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: FloatingActionButton.extended(
        onPressed: () {
          // Only allow creating owner or finder accounts
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Add User', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                const SizedBox(height: 8),
                Text('Create a new user account for Brgy. $_adminBarangay', style: GoogleFonts.inter(fontSize: 13, color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person, color: AppColors.primary, size: 20)),
                  title: Text('Pet Owner', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Can register and manage pets', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF9333EA).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.search, color: Color(0xFF9333EA), size: 20)),
                  title: Text('Finder', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Can report and scan found pets', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                  onTap: () => Navigator.pop(context),
                ),
                if (_currentUserRole == UserRole.superAdmin) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primaryContainer.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                    ),
                    title: Text('Barangay Admin', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('Can manage this barangay\'s news and pets', style: GoogleFonts.inter(fontSize: 12, color: AppColors.onSurfaceVariant)),
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ]),
            ),
          );
        },
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        icon: const Icon(Icons.add),
        label: Text('Add User', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700)),
        elevation: 8,
        extendedIconLabelSpacing: 6,
      ),
    );
  }
}
