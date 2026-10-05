import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_constants.dart';
import '../../../core/app_toast.dart';
import '../../../services/auth/auth_service.dart';

/// Modal dialog for registering a Barangay Admin from UserManagementScreen.
class AddAdminDialog extends StatefulWidget {
  final VoidCallback onAdminRegistered;

  const AddAdminDialog({
    super.key,
    required this.onAdminRegistered,
  });

  static void show(
    BuildContext context, {
    required VoidCallback onAdminRegistered,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AddAdminDialog(
        onAdminRegistered: onAdminRegistered,
      ),
    );
  }

  @override
  State<AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fNameCtrl = TextEditingController();
  final _sNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _selectedBrgy = AppConstants.barangays.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fNameCtrl.dispose();
    _sNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
        data: {
          'first_name': _fNameCtrl.text.trim(),
          'surname': _sNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'barangay': _selectedBrgy,
          'role': 'admin',
        },
      );
      if (mounted) Navigator.pop(context);
      widget.onAdminRegistered();
      if (mounted) {
        AppToast.success(context, 'Admin registered for Brgy. $_selectedBrgy!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppToast.error(context, 'Failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Color(0xFF00796B),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Register Barangay Admin',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _fNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'First Name *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      AuthService.validateName(v, fieldName: 'First Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Surname *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                    labelText: 'Email *',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) => v != null && v.trim().isNotEmpty
                      ? AuthService.validatePhone(v, isRequired: false)
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Temp Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: AuthService.validatePassword,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedBrgy,
                  decoration: InputDecoration(
                    labelText: 'Assigned Barangay *',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: AppConstants.barangays
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text('Brgy. $b'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBrgy = val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Register Admin'),
        ),
      ],
    );
  }
}
