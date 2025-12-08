import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Initial Setup Screen untuk mode produksi
/// Ditampilkan saat pertama kali aplikasi dijalankan (tanpa demo data)
class InitialSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onSetupComplete;

  const InitialSetupScreen({super.key, required this.onSetupComplete});

  @override
  ConsumerState<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends ConsumerState<InitialSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;

  @override
  void dispose() {
    _storeNameController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now().toIso8601String();
      final tenantId = 'tenant-${DateTime.now().millisecondsSinceEpoch}';
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      final passwordHash = _passwordController.text.hashCode.toString();

      if (!kIsWeb) {
        final db = await DatabaseHelper.instance.database;

        // Create tenant
        await db.insert('tenants', {
          'id': tenantId,
          'name': _storeNameController.text.trim(),
          'identifier': _storeNameController.text
              .trim()
              .toLowerCase()
              .replaceAll(' ', '-'),
          'timezone': 'Asia/Jakarta',
          'currency': 'IDR',
          'tax_rate': 0.11,
          'created_at': now,
          'updated_at': now,
        });

        // Create owner user
        await db.insert('users', {
          'id': userId,
          'tenant_id': tenantId,
          'email': _ownerEmailController.text.trim(),
          'name': _ownerNameController.text.trim(),
          'password_hash': passwordHash,
          'role': 'owner',
          'is_active': 1,
          'created_at': now,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Setup berhasil! Silakan login.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        widget.onSetupComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup gagal: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const Icon(Icons.store,
                        size: 64, color: AppTheme.primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Selamat Datang!',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mari siapkan toko Anda',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Stepper
                    _buildStepper(),
                    const SizedBox(height: 24),

                    // Form Content
                    if (_currentStep == 0) _buildStoreInfoStep(),
                    if (_currentStep == 1) _buildOwnerInfoStep(),
                    if (_currentStep == 2) _buildConfirmStep(),

                    const SizedBox(height: 24),

                    // Navigation Buttons
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: [
        _buildStepIndicator(0, 'Toko'),
        Expanded(
            child: Container(
                height: 2,
                color: _currentStep > 0
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor)),
        _buildStepIndicator(1, 'Owner'),
        Expanded(
            child: Container(
                height: 2,
                color: _currentStep > 1
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor)),
        _buildStepIndicator(2, 'Selesai'),
      ],
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor : AppTheme.borderColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isActive && _currentStep > step
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppTheme.primaryColor : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informasi Toko',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _storeNameController,
          decoration: const InputDecoration(
            labelText: 'Nama Toko *',
            prefixIcon: Icon(Icons.store),
            hintText: 'Contoh: Kopi Ku Coffee Shop',
          ),
          validator: (v) =>
              v?.trim().isEmpty == true ? 'Nama toko wajib diisi' : null,
        ),
      ],
    );
  }

  Widget _buildOwnerInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Akun Owner',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ownerNameController,
          decoration: const InputDecoration(
            labelText: 'Nama Lengkap *',
            prefixIcon: Icon(Icons.person),
          ),
          validator: (v) =>
              v?.trim().isEmpty == true ? 'Nama wajib diisi' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ownerEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email *',
            prefixIcon: Icon(Icons.email),
          ),
          validator: (v) {
            if (v?.trim().isEmpty == true) return 'Email wajib diisi';
            if (!v!.contains('@')) return 'Email tidak valid';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password *',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v?.isEmpty == true) return 'Password wajib diisi';
            if (v!.length < 6) return 'Password minimal 6 karakter';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Konfirmasi Password *',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          validator: (v) {
            if (v != _passwordController.text) return 'Password tidak cocok';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConfirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Konfirmasi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildConfirmItem('Nama Toko', _storeNameController.text),
        _buildConfirmItem('Nama Owner', _ownerNameController.text),
        _buildConfirmItem('Email', _ownerEmailController.text),
        _buildConfirmItem('Pajak Default', '11%'),
        _buildConfirmItem('Mata Uang', 'IDR'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.warningColor),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pastikan data sudah benar. Email dan password akan digunakan untuk login.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: AppTheme.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Kembali'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
                    if (_currentStep < 2) {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _currentStep++);
                      }
                    } else {
                      _completeSetup();
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_currentStep < 2 ? 'Lanjut' : 'Selesai & Mulai'),
          ),
        ),
      ],
    );
  }
}
