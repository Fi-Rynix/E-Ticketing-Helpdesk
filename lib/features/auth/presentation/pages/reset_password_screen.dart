import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  // Mode 1: email input
  final _emailController = TextEditingController();

  // Mode 2: new password
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isRecoveryMode = false;

  @override
  void initState() {
    super.initState();
    _checkRecoveryMode();
  }

  /// Check if we arrived here from a password recovery deep link
  void _checkRecoveryMode() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // User has a session from clicking the recovery link
      setState(() => _isRecoveryMode = true);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Mode 1: Send reset link
  void _handleSendResetLink() async {
    if (_emailController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email');
      return;
    }

    final email = _emailController.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = AuthRepository();
      final success = await authRepo.resetPassword(email);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent! Check your email.'),
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to send reset email.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  /// Mode 2: Update password (arrived via deep link)
  void _handleUpdatePassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill both password fields');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = AuthRepository();
      final success = await authRepo.updatePassword(_newPasswordController.text);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully! Please log in.')),
        );
        // Sign out and navigate to login
        await Supabase.instance.client.auth.signOut();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to update password. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRecoveryMode ? 'Set New Password' : 'Reset Password'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _isRecoveryMode ? _buildRecoveryMode() : _buildEmailMode(),
      ),
    );
  }

  Widget _buildEmailMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Forgot Your Password?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email address and we\'ll send you a link to reset your password.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) _buildErrorBox(),
        if (_errorMessage != null) const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isLoading,
          decoration: const InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSendResetLink,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send Reset Link'),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Already remember? '),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Back to Login'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecoveryMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Set New Password',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your new password below.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) _buildErrorBox(),
        if (_errorMessage != null) const SizedBox(height: 16),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          enabled: !_isLoading,
          decoration: const InputDecoration(
            labelText: 'New Password',
            prefixIcon: Icon(Icons.lock),
            helperText: 'Minimum 6 characters',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          enabled: !_isLoading,
          decoration: const InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: Icon(Icons.lock),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleUpdatePassword,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Update Password'),
        ),
      ],
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
    );
  }
}