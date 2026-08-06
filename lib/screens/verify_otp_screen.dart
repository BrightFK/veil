import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final String password;
  final String username;
  const VerifyOtpScreen({
    super.key,
    required this.email,
    required this.password,
    required this.username,
  });

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(authProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Verify Email'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF0F0F0F)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.email_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Check your email',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification code to\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // Glassmorphism card
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // OTP Input
                            TextField(
                              controller: _otpController,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                              keyboardType: TextInputType.text,
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: 'Paste the code from your email',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Error message
                            if (_error != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Verify Button
                            CustomButton(
                              isLoading: _loading,
                              label: 'Verify & Create Account',
                              onPressed: () => _verifyOtp(notifier),
                            ),

                            const SizedBox(height: 16),

                            // Resend
                            Center(
                              child: TextButton(
                                onPressed: _loading
                                    ? null
                                    : () async {
                                        await notifier.resendConfirmation(
                                          widget.email,
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'New code sent to your email',
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                child: const Text(
                                  'Resend code',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _verifyOtp(AuthNotifier notifier) async {
    final token = _otpController.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Please paste the verification code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await notifier.verifyOtpAndSignIn(
      email: widget.email,
      otp: token,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      final state = ref.read(authProvider);
      setState(() => _error = state.errorMessage ?? 'Verification failed');
    }
  }
}
