import 'package:flutter/material.dart';

/// Shows a transient message that floats above EVERYTHING — including modal
/// bottom sheets and dialogs.
///
/// Uses an [OverlayEntry] on the root [Overlay], which is above the modal
/// route layer that hides ScaffoldMessenger snackbars.
void showAppSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppSnackBanner(
      message: message,
      isError: isError,
      duration: duration,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// Convenience for error messages.
void showAppError(BuildContext context, Object error) {
  final raw = error is String ? error : error.toString();
  final clean = raw.replaceFirst('Exception: ', '');
  showAppSnack(context, clean, isError: true);
}

class _AppSnackBanner extends StatefulWidget {
  const _AppSnackBanner({
    required this.message,
    required this.isError,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_AppSnackBanner> createState() => _AppSnackBannerState();
}

class _AppSnackBannerState extends State<_AppSnackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.isError ? scheme.errorContainer : scheme.inverseSurface;
    final fg =
        widget.isError ? scheme.onErrorContainer : scheme.onInverseSurface;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final padding = MediaQuery.paddingOf(context).bottom;
    // Sit well above typical bottom navigation / floating action bars so the
    // banner doesn't overlap interactive elements like "Add to order".
    return Positioned(
      left: 16,
      right: 16,
      bottom: viewInsets + padding + 88,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 16,
                      color: Colors.black26,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.isError) ...[
                      Icon(Icons.error_outline, color: fg, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
