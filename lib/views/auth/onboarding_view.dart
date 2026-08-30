import 'package:flutter/material.dart';

import '../../models/waste_category.dart';
import '../../utils/app_theme.dart';

/// Introduces the three UGM waste categories right after sign-in.
///
/// Content comes from [WasteCategory] rather than a parallel hardcoded list,
/// so onboarding, the home cards and the result screen can never disagree
/// about a category's name, colour or bin.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _categories = WasteCategory.values;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Onboarding sits on top of the HomeView that AuthWrapper already built,
  /// so finishing just pops back to it.
  void _finish() => Navigator.of(context).pop();

  void _next() {
    if (_currentPage < _categories.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _categories.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                  child: const Text('Lewati'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _categories.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _buildPage(_categories[index]),
              ),
            ),
            _buildDots(),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isLast ? AppTheme.greenPrimary : AppTheme.navyPrimary,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLast ? 'Mulai' : 'Selanjutnya'),
                      if (!isLast) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(WasteCategory category) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final circleSize = (constraints.maxWidth * 0.45).clamp(120.0, 192.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: category.bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    category.icon,
                    size: circleSize * 0.5,
                    color: category.color,
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  category.officialName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
                // Bin colour is the actionable takeaway of the education step.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: category.bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: category.color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: category.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          category.binLabel,
                          style: TextStyle(
                            color: category.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  category.onboardingDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Contoh: ${category.examplesText}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _categories.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 32 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? AppTheme.navyPrimary
                : const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
