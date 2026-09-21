import 'dart:math';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/admin_content_wrapper.dart';
import '../../widgets/admin_layout.dart';
import 'web/admin_web_layout.dart';

/// News & Announcements management screen for PawTrace Admins.
///
/// Integrated directly within the [AdminLayout] navigation shell (Tab index 4).
class PostNewsScreen extends StatefulWidget {
  const PostNewsScreen({super.key});

  @override
  State<PostNewsScreen> createState() => _PostNewsScreenState();
}

class _PostNewsScreenState extends State<PostNewsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _sourceCtrl = TextEditingController(text: 'PawTrace Updates');
  final _summaryCtrl = TextEditingController();

  XFile? _pickedFile;
  Uint8List? _imageBytes;

  String _selectedCategory = 'Community Alert';
  String _selectedColorHex = '#FF6600';
  bool _isLoading = false;
  bool _isLoadingPosts = true;

  List<Map<String, dynamic>> _newsPosts = [];
  String _adminBarangay = '';
  UserRole _currentUserRole = UserRole.user;

  final List<String> _categories = [
    'Community Alert',
    'Lost & Found',
    'Safety Tips',
    'General Update'
  ];

  final Map<String, String> _accentColors = {
    'Orange': '#FF6600',
    'Green': '#00796B',
    'Blue': '#4E7AC7',
    'Red': '#BA1A1A',
    'Purple': '#8E24AA'
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _adminBarangay = await AuthService.instance.getCurrentUserBarangay();
    _currentUserRole = await AuthService.instance.getCurrentUserRole();
    _fetchNewsPosts();
  }

  Future<void> _fetchNewsPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      var query = Supabase.instance.client.from('news').select();
      if (_currentUserRole != UserRole.superAdmin && _adminBarangay.isNotEmpty) {
        query = query.eq('barangay', _adminBarangay);
      }
      final data = await query.order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _newsPosts = List<Map<String, dynamic>>.from(data);
          _isLoadingPosts = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching news: $e');
      if (mounted) setState(() => _isLoadingPosts = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sourceCtrl.dispose();
    _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedFile = picked;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _submitNews() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      String? photoUrl;
      if (_pickedFile != null && _imageBytes != null) {
        final fileExt = _pickedFile!.name.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final randomSuffix =
            Random().nextInt(999999).toString().padLeft(6, '0');
        final fileName = 'news/${timestamp}_$randomSuffix.$fileExt';

        await Supabase.instance.client.storage
            .from('pet-photos')
            .uploadBinary(fileName, _imageBytes!);

        photoUrl = Supabase.instance.client.storage
            .from('pet-photos')
            .getPublicUrl(fileName);
      }

      await Supabase.instance.client.from('news').insert({
        'category': _selectedCategory,
        'title': _titleCtrl.text.trim(),
        'source': _sourceCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim(),
        'image_url': photoUrl,
        'accent_color': _selectedColorHex,
        'barangay': _adminBarangay.isNotEmpty ? _adminBarangay : 'Catanduanes',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('News post published successfully!',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      _titleCtrl.clear();
      _summaryCtrl.clear();
      setState(() {
        _pickedFile = null;
        _imageBytes = null;
      });

      _fetchNewsPosts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting news: $e',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    final postId =
        (post['news_id'] ?? post['post_id'] ?? post['id'])?.toString() ?? '';
    final title = post['title']?.toString() ?? 'this post';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Post?',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete "$title"? This will permanently remove the news post.',
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
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      bool deleted = false;
      for (final idCol in ['news_id', 'post_id', 'id']) {
        if (postId.isNotEmpty) {
          try {
            await Supabase.instance.client
                .from('news')
                .delete()
                .eq(idCol, postId);
            deleted = true;
            break;
          } catch (_) {}
        }
      }
      if (!deleted && title.isNotEmpty) {
        await Supabase.instance.client.from('news').delete().eq('title', title);
      }
      _fetchNewsPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('News post deleted successfully.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).isDesktop) {
      return _buildDesktopLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: AdminLayout(
        currentIndex: 4,
        pageTitle: 'News & Announcements',
        role: _currentUserRole,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return AdminWebLayout(
      currentIndex: 4,
      pageTitle: 'News & Announcements',
      body: Stack(
        children: [
          _buildWideLayout(isWebLayout: true),
          if (_isLoading)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildAppBar(context),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _fetchNewsPosts,
                color: AppColors.primary,
                child: AdminContentWrapper(
                  maxWidth: 1100,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      return isWide
                          ? _buildWideLayout()
                          : _buildNarrowLayout();
                    },
                  ),
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 800) return const SizedBox.shrink();
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
            'News & Announcements',
            style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface),
          ),
        ],
      ),
    );
  }

  // ─── WIDE LAYOUT (Desktop / Web) ──────────────────────────────────────────

  Widget _buildWideLayout({bool isWebLayout = false}) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: Create announcement form
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildForm(isWide: true),
          ),
        ),
        const SizedBox(width: 24),
        // Right column: Published News list
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostsHeader(),
              const SizedBox(height: 14),
              _buildPostsList(),
            ],
          ),
        ),
      ],
    );

    if (isWebLayout) {
      return content;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: content,
    );
  }

  // ─── NARROW LAYOUT (Mobile) ────────────────────────────────────────────────

  Widget _buildNarrowLayout() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _buildForm(isWide: false),
        const SizedBox(height: 32),
        const Divider(height: 1, color: AppColors.surfaceContainer),
        const SizedBox(height: 24),
        _buildPostsHeader(),
        const SizedBox(height: 14),
        _buildPostsList(),
      ],
    );
  }

  Widget _buildPostsHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.article_rounded,
              color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          'Published News',
          style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.primary),
          tooltip: 'Refresh',
          onPressed: _fetchNewsPosts,
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_newsPosts.length} Posts',
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsList() {
    if (_isLoadingPosts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_newsPosts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.campaign_outlined,
                size: 40, color: AppColors.outlineVariant),
            const SizedBox(height: 10),
            Text(
              'No news published yet.',
              style: GoogleFonts.inter(
                  color: AppColors.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Column(
      children: _newsPosts
          .map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPostCard(post),
              ))
          .toList(),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final title = post['title'] as String? ?? 'Untitled';
    final summary = post['summary'] as String? ?? '';
    final category = post['category'] as String? ?? '';
    final imageUrl = post['image_url'] as String? ?? '';
    final accentHex = post['accent_color'] as String? ?? '#FF6600';
    final barangay = post['barangay'] as String? ?? '';

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
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14)),
              child: Image.network(
                imageUrl,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 76,
                  height: 76,
                  color: accentColor.withOpacity(0.15),
                  child: Icon(Icons.article_rounded,
                      color: accentColor, size: 28),
                ),
              ),
            )
          else
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14)),
              ),
              child:
                  Icon(Icons.article_rounded, color: accentColor, size: 28),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (category.isNotEmpty)
                        Container(
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
                      if (barangay.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('• Brgy. $barangay',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.6))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
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
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 20),
            tooltip: 'Delete post',
            onPressed: () => _deletePost(post),
          ),
        ],
      ),
    );
  }

  // ─── CREATE POST FORM ─────────────────────────────────────────────────────

  Widget _buildForm({required bool isWide}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_box_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Create New Announcement',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Publish community alerts, lost pet notices, or general updates.',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // Category Dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedCategory,
            decoration: _inputDecoration(
              hint: 'Category',
              icon: Icons.category_outlined,
            ),
            items: _categories.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v!),
          ),
          const SizedBox(height: 14),

          // Title Field
          TextFormField(
            controller: _titleCtrl,
            style:
                GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
            decoration:
                _inputDecoration(hint: 'Title', icon: Icons.title_rounded),
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Title is required'
                : null,
          ),
          const SizedBox(height: 14),

          // Source Field
          TextFormField(
            controller: _sourceCtrl,
            style:
                GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
            decoration: _inputDecoration(
                hint: 'Source / Author', icon: Icons.edit_note_rounded),
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Source is required'
                : null,
          ),
          const SizedBox(height: 14),

          // News Image Picker Field
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: isWide ? 170 : 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.25),
                    width: 1.5),
                image: _imageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_imageBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined,
                            size: 32, color: AppColors.secondary),
                        const SizedBox(height: 6),
                        Text('Choose Image (Optional)',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceVariant)),
                      ],
                    )
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
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Accent Color Dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedColorHex,
            decoration: _inputDecoration(
              hint: 'Accent Theme Color',
              icon: Icons.palette_outlined,
            ),
            items: _accentColors.entries.map((entry) {
              final name = entry.key;
              final hex = entry.value;
              final color = Color(
                  int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              return DropdownMenuItem(
                value: hex,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedColorHex = v!),
          ),
          const SizedBox(height: 14),

          // Summary/Content Field
          TextFormField(
            controller: _summaryCtrl,
            style:
                GoogleFonts.inter(fontSize: 14, color: AppColors.onSurface),
            decoration: _inputDecoration(
                hint: 'Summary or news message details...',
                icon: Icons.description_outlined),
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Summary content is required'
                : null,
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitNews,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(
                'Publish Announcement',
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      {required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.secondary, size: 18),
      filled: true,
      fillColor: AppColors.surfaceContainerLowest,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}
