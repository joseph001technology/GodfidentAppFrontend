import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/auth_repository.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? token;
  const VerifyEmailScreen({super.key, this.token});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _repo = AuthRepository();
  bool _loading = false;
  bool _verifying = false;
  bool? _verified;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.token != null && widget.token!.isNotEmpty) {
      Future.microtask(_verify);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      await _repo.verifyEmail(widget.token!);
      if (mounted) {
        setState(() {
          _verified = true;
          _message = 'Your email has been verified. You can sign in now.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verified = false;
          _message = 'This verification link is invalid or expired.';
        });
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _loading = true);
    try {
      await _repo.resendVerification();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email resent!')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to resend. Please try again.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _verified == true
                    ? Icons.mark_email_read_outlined
                    : _verified == false
                        ? Icons.error_outline
                        : Icons.email_outlined,
                size: 72,
                color: _verified == false ? Colors.redAccent : const Color(0xFFC9A96E),
              ),
              const SizedBox(height: 24),
              Text(
                _verified == true ? 'Email Verified' : 'Verify Your Email',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                _message ??
                    'We sent a verification link to your email. Click it to activate your account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (_verifying)
                const CircularProgressIndicator()
              else if (_verified == true)
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Continue to Login'),
                )
              else
                ElevatedButton(
                  onPressed: _loading ? null : _resend,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Resend Email'),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
