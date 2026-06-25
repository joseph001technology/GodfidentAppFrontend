import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/dio_client.dart';
import '../../core/theme.dart';
import '../../repositories/auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() => _error = 'This reset link is missing a token.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthRepository().resetPassword(
        token: widget.token!,
        newPassword: _password.text,
        newPasswordConfirm: _confirm.text,
      );
      if (mounted) setState(() => _done = true);
    } on DioException catch (e) {
      if (mounted) setState(() => _error = extractError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Password')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 32),
          Icon(
            _done ? Icons.check_circle_outline : Icons.lock_reset,
            color: _done ? Colors.green : AppTheme.gold,
            size: 72,
          ),
          const SizedBox(height: 20),
          Text(
            _done ? 'Password updated' : 'Reset your password',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _done
                ? 'You can now sign in with your new password.'
                : 'Choose a strong password for your Godfident account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          if (_done)
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Login'),
            )
          else
            Form(
              key: _form,
              child: Column(
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 8) {
                        return 'Use at least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reset Password'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
