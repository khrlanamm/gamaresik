import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'onboarding_view.dart';

class AuthView extends StatelessWidget {
  const AuthView({super.key});

  Future<void> _signIn(BuildContext context, AuthViewModel viewModel) async {
    final result = await viewModel.signInWithGoogle();
    if (!context.mounted) return;

    switch (result) {
      case GoogleSignInResult.success:
        // AuthWrapper reacts to authStateChanges and puts HomeView underneath,
        // so onboarding is pushed *on top* of it and simply popped when done.
        // Using pushReplacement here would leave two HomeViews stacked.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingView()),
        );
      case GoogleSignInResult.cancelled:
        break;
      case GoogleSignInResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal masuk. Silakan coba lagi.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // Scrollable so the hero block cannot overflow on short screens
              // or at large accessibility text scales.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          Expanded(child: _buildHero(context, constraints)),
                          _buildSignInSection(context, viewModel),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHero(BuildContext context, BoxConstraints constraints) {
    // Scale the logo with the viewport instead of pinning it at 144px, which
    // was a large share of the vertical space on small phones.
    final logoSize = (constraints.maxWidth * 0.34).clamp(96.0, 144.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset('assets/brands/logo_icon.png'),
          ),
          const SizedBox(height: 28),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Gama',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'Waste',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.greenPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aplikasi Pemilah Sampah',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola sampah dengan cerdas, lindungi lingkungan untuk masa depan '
            'yang lebih baik',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSignInSection(BuildContext context, AuthViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF0F7FF).withValues(alpha: 0.0),
            const Color(0xFFF0F7FF),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => _signIn(context, viewModel),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  side: const BorderSide(color: AppTheme.borderSubtle),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleMark(),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Masuk dengan Google',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Dengan masuk, Anda menyetujui syarat dan ketentuan kami',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// A local, network-free stand-in for the Google "G" mark. The previous
/// version fetched an .svg via Image.network — a format Flutter's built-in
/// image decoder can't render, so it silently fell back to a generic icon
/// on every launch.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF4285F4),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
