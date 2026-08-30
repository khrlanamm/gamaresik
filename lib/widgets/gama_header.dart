import 'package:flutter/material.dart';

import '../utils/app_theme.dart';

/// The navy gradient header used across the app.
///
/// Pads for the real status bar height via [SafeArea] instead of the hardcoded
/// top inset each screen used to carry, which clipped on devices with taller
/// status bars and left a gap on shorter ones.
class GamaHeader extends StatelessWidget {
  final String title;

  /// Shown when the route can be popped; set false for root screens.
  final bool showBack;
  final Widget? trailing;
  final Widget? bottom;
  final EdgeInsets padding;

  const GamaHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.trailing,
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBack) ...[
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      tooltip: 'Kembali',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              ?bottom,
            ],
          ),
        ),
      ),
    );
  }
}

/// A centred icon + message block used for empty, error and offline states.
///
/// Always scrollable so it can sit inside a [RefreshIndicator] and still be
/// pull-to-refreshable when the content is shorter than the viewport.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: iconColor ?? AppTheme.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (onAction != null && actionLabel != null) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
