import 'dart:io';
import 'dart:math';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../services/auth_service.dart';

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
  File? _selectedImage;
  
  String _selectedCategory = 'Community Alert';
  String _selectedColorHex = '#FF6600';
  bool _isLoading = false;

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
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submitNews() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final adminBarangay = await AuthService.instance.getCurrentUserBarangay();

      String? photoUrl;
      if (_selectedImage != null) {
        final fileExt = _selectedImage!.path.split('.').last;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final randomSuffix = Random().nextInt(999999).toString().padLeft(6, '0');
        final fileName = 'news/${timestamp}_$randomSuffix.$fileExt';

        await Supabase.instance.client.storage
            .from('pet-photos')
            .upload(fileName, _selectedImage!);

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
        'barangay': adminBarangay,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('News posted successfully!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting news: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'Post News Update',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.onSurface),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share announcements or updates with the PawTrace community.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

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
                  const SizedBox(height: 16),

                  // Title Field
                  TextFormField(
                    controller: _titleCtrl,
                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
                    decoration: _inputDecoration(hint: 'Title', icon: Icons.title_rounded),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Source Field
                  TextFormField(
                    controller: _sourceCtrl,
                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
                    decoration: _inputDecoration(hint: 'Source / Author', icon: Icons.edit_note_rounded),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Source is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // News Image Picker Field
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.outlineVariant.withOpacity(0.2),
                            width: 1.5),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  const Icon(Icons.add_photo_alternate_outlined,
                                      size: 36, color: AppColors.secondary),
                                  const SizedBox(height: 6),
                                  Text('Tap to Choose Photo (Gallery)',
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.onSurfaceVariant)),
                                ])
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
                  const SizedBox(height: 16),

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
                      final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                      return DropdownMenuItem(
                        value: hex,
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Text(name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedColorHex = v!),
                  ),
                  const SizedBox(height: 16),

                  // Summary/Content Field
                  TextFormField(
                    controller: _summaryCtrl,
                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.onSurface),
                    decoration: _inputDecoration(hint: 'Summary or news message details...', icon: Icons.description_outlined),
                    maxLines: 6,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Summary content is required' : null,
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitNews,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        'Publish News',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
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
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}
