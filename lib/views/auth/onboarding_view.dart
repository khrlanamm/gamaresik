import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../home/home_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Sampah Organik',
      description: 'Material yang dapat terurai secara alami seperti sisa makanan, kulit buah, dan daun kering.',
      icon: Icons.eco_rounded,
      color: const Color(0xFF0CAA4E),
      bgColor: const Color(0xFFE6F7EE),
    ),
    OnboardingData(
      title: 'Sampah Recycle Bersih',
      description: 'Material non-organik bernilai daur ulang seperti botol plastik, kertas, dan kardus yang dibuang dalam kondisi bersih dan kering.',
      icon: Icons.recycling_rounded,
      color: const Color(0xFFFFC107),
      bgColor: const Color(0xFFFFF9C4),
    ),
    OnboardingData(
      title: 'Sampah Residu',
      description: 'Material sisa yang tidak dapat didaur ulang seperti kemasan sachet, bungkus kotor berminyak, tisu, dan masker.',
      icon: Icons.delete_outline_rounded,
      color: const Color(0xFFF44336),
      bgColor: const Color(0xFFFFEBEE),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeView()),
                    );
                  },
                  child: const Text(
                    'Lewati',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Circle
                        Container(
                          width: 192,
                          height: 192,
                          decoration: BoxDecoration(
                            color: page.bgColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            page.icon,
                            size: 96,
                            color: page.color,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navyPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Color accent bar
                        Container(
                          width: 48,
                          height: 4,
                          decoration: BoxDecoration(
                            color: page.color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Dots Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
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
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom Section
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeView()),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPage == _pages.length - 1
                        ? AppTheme.greenPrimary
                        : AppTheme.navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentPage == _pages.length - 1 ? 'Mulai' : 'Selanjutnya',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_currentPage < _pages.length - 1) ...[
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
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color bgColor;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
