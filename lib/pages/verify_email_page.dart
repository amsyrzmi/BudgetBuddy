import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isSending = false;
  String _message = '';

  Future<void> _resendVerification() async {
    setState(() {
      _isSending = true;
      _message = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      setState(() => _message = 'Verification email sent!');
    } catch (e) {
      setState(() => _message = 'Failed to send: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    final refreshed = FirebaseAuth.instance.currentUser;

    if (refreshed != null && refreshed.emailVerified) {
      // AuthGate's stream will automatically navigate to NavigationWrapper
      return;
    }

    setState(
      () => _message = 'Email not verified yet. Please check your inbox.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 64,
                  color: Color(0xFF1D9E75),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify your email',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a verification link to:\n${user?.email ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _message.contains('sent')
                            ? Colors.green
                            : Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _checkVerified,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D9E75),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("I've verified my email"),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSending ? null : _resendVerification,
                  child: _isSending
                      ? const CircularProgressIndicator()
                      : const Text('Resend verification email'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
