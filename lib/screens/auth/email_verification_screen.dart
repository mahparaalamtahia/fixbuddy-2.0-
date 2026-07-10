import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';

final _supabase = Supabase.instance.client;

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  bool _isResending = false;
  bool _isChecking = false;

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        await _supabase.auth.resend(
          type: OtpType.signup,
          email: user.email!,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email resent!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      await _supabase.auth.refreshSession();
      final user = _supabase.auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        final data = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .single();
        final role = data['role'] as String? ?? 'user';
        if (!mounted) return;
        if (role == 'worker') {
          final workerData = await _supabase
              .from('workers')
              .select('id')
              .eq('profile_id', user.id)
              .maybeSingle();
          if (!mounted) return;
          if (workerData != null) {
            context.go('/worker-profile-setup',
                extra: workerData['id'] as String);
          } else {
            context.go('/worker-shell');
          }
        } else {
          context.go('/shell');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not verified yet. Please check your inbox.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread,
                  size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Verify Your Email',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'We have sent a verification email to your registered email address. Please check your inbox and click the verification link.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Resend Verification Email',
                isLoading: _isResending,
                onPressed: _resendEmail,
              ),
              const SizedBox(height: 12),
              CustomButton(
                label: 'I\'ve Verified - Continue',
                isLoading: _isChecking,
                onPressed: _checkVerification,
                isOutlined: true,
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await _supabase.auth.signOut();
                  if (context.mounted) context.go('/login');
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
