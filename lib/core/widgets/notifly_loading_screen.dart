import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'notifly_logo.dart';

/// Full-screen or embedded loading widget with centered animated NotiFly Logo
class NotiFlyLoadingScreen extends StatefulWidget {
  const NotiFlyLoadingScreen({
    super.key,
    this.message = 'Loading...',
    this.logoSize = 130,
    this.isFullScreen = true,
  });

  final String message;
  final double logoSize;
  final bool isFullScreen;

  @override
  State<NotiFlyLoadingScreen> createState() => _NotiFlyLoadingScreenState();
}

class _NotiFlyLoadingScreenState extends State<NotiFlyLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Centered Animated Logo
            ScaleTransition(
              scale: _scaleAnim,
              child: FadeTransition(
                opacity: _opacityAnim,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.messengerBlue.withValues(alpha: 0.08)
                        : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.messengerBlue.withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: NotiFlyLogo(
                    size: widget.logoSize,
                    showText: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Smooth Progress Indicator
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.messengerBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Loading Message Text
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppColors.lightText,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    if (widget.isFullScreen) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: content,
      );
    }

    return content;
  }
}
