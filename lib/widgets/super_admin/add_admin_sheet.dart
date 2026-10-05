import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/app_toast.dart';
import '../../services/auth/auth_service.dart';

/// Modal bottom sheet for registering a new Barangay Admin in SuperAdmin screen.
class AddAdminSheet extends StatefulWidget {
  final List<String> municipalities;
  final VoidCallback onAdminRegistered;

  const AddAdminSheet({
    super.key,
    required this.municipalities,
    required this.onAdminRegistered,
  });

  static void show(
    BuildContext context, {
    required List<String> municipalities,
    required VoidCallback onAdminRegistered,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddAdminSheet(
        municipalities: municipalities,
        onAdminRegistered: onAdminRegistered,
      ),
    );
  }

  @override
  State<AddAdminSheet> createState() => _AddAdminSheetState();
}

class _AddAdminSheetState extends State<AddAdminSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late String _selectedMunicipality;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _selectedMunicipality = widget.municipalities.contains('Virac')
        ? 'Virac'
        : widget.municipalities.first;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final fName = _firstNameCtrl.text.trim();
    final sName = _surnameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() => _isRegistering = true);

    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': fName,
          'surname': sName,
          'phone': phone,
          'barangay': _selectedMunicipality,
          'role': 'admin',
        },
      );

      if (mounted) {
        AppToast.success(context, 'Barangay Admin registered successfully!');
        _firstNameCtrl.clear();
        _surnameCtrl.clear();
        _emailCtrl.clear();
        _phoneCtrl.clear();
        _passwordCtrl.clear();
        Navigator.pop(context);
        widget.onAdminRegistered();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Failed to register admin: $e');
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Register Barangay Admin',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Assign a new admin to a municipality in Catanduanes.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _firstNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'First Name *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) =>
                    AuthService.validateName(v, fieldName: 'First Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _surnameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Surname *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) =>
                    AuthService.validateName(v, fieldName: 'Surname'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: AuthService.validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (v) => v != null && v.trim().isNotEmpty
                    ? AuthService.validatePhone(v, isRequired: false)
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Temp Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: AuthService.validatePassword,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedMunicipality,
                decoration: InputDecoration(
                  labelText: 'Assigned Municipality',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: widget.municipalities
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMunicipality = val);
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isRegistering ? null : _registerAdmin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isRegistering
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Register Admin',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
