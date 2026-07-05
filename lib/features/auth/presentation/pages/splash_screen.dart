import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;

  void _navigateAfterInit() {
    if (_navigated) return;
    _navigated = true;

    // Wait minimal splash time (1.5s) for branding
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user != null) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth init — when done, navigate
    ref.listen<AsyncValue<dynamic>>(initAuthProvider, (previous, next) {
      next.whenData((_) => _navigateAfterInit());
    });

    // Trigger init on first build
    ref.read(initAuthProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF000072),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'E-Ticketing Helpdesk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
