import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';

/// One labelled action in a [GlassFabMenu].
class GlassFabAction<T> {
  final Key key;
  final T value;
  final IconData icon;
  final Color color;
  final String label;

  const GlassFabAction({
    required this.key,
    required this.value,
    required this.icon,
    required this.color,
    required this.label,
  });
}

/// Floating menu that expands from a FAB: lightly dimmed backdrop, white labelled
/// pills and a close button drawn exactly over the FAB.
class GlassFabMenu<T> extends StatelessWidget {
  final Rect fabRect;
  final Animation<double> animation;
  final List<GlassFabAction<T>> actions;
  final Key closeKey;
  final Key backdropKey;

  const GlassFabMenu({
    super.key,
    required this.fabRect,
    required this.animation,
    required this.actions,
    required this.closeKey,
    required this.backdropKey,
  });

  // Keyed by navigator so a discarded app tree can never leave a button locked.
  static final Expando<bool> _busy = Expando<bool>();

  /// Runs [flow] unless a menu or its chosen form is already open, which stops a
  /// repeated tap opening a second one. [context] must be the FAB's own context.
  static Future<void> guarded(BuildContext context, Future<void> Function(NavigatorState navigator, Rect fabRect) flow) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (_busy[navigator] == true) return;
    _busy[navigator] = true;
    try {
      final box = context.findRenderObject() as RenderBox;
      await flow(navigator, box.localToGlobal(Offset.zero) & box.size);
    } finally {
      _busy[navigator] = null;
    }
  }

  /// Shows the menu built by [builder] and returns the chosen value only once the
  /// menu has fully closed; opened sooner, the second tap of a double tap lands
  /// on the next form's barrier and dismisses it.
  static Future<T?> present<T>(
    NavigatorState navigator,
    Widget Function(Animation<double> animation) builder,
  ) async {
    final route = PageRouteBuilder<T>(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, animation, _) => builder(animation),
    );
    final choice = await navigator.push(route);
    await route.completed;
    return choice;
  }

  static const double _rowHeight = 54;
  static const double _rowGap = 8;
  static const double _fabGap = 12;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final right = screen.width - fabRect.right;
    final stackBottom = screen.height - fabRect.top + _fabGap;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: backdropKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: AnimatedBuilder(
                animation: animation,
                builder: (_, _) => ColoredBox(color: Colors.black.withValues(alpha: 0.14 * animation.value)),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: animation,
                child: CustomPaint(
                  painter: _ConnectorPainter(
                    fabRect: fabRect,
                    topRowY: fabRect.top - _fabGap - _rowGap * (actions.length - 1) - _rowHeight * (actions.length - 0.5),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: right,
            bottom: stackBottom,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screen.width - right - 12),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: _rowGap),
                      _ActionRow<T>(
                        key: actions[i].key,
                        action: actions[i],
                        // The lowest item leads, as the stack grows up from the button.
                        animation: CurvedAnimation(
                          parent: animation,
                          curve: Interval(0.2 * (actions.length - 1 - i), 1, curve: Curves.easeOutCubic),
                        ),
                        onTap: () => Navigator.pop(context, actions[i].value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: fabRect,
            child: FloatingActionButton(
              key: closeKey,
              heroTag: null,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Close',
              onPressed: () => Navigator.pop(context),
              child: RotationTransition(
                turns: Tween<double>(begin: -0.125, end: 0).animate(animation),
                child: const GlassFabFace(icon: LucideIcons.x),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glossy green face shared by each FAB and its menu's close button.
class GlassFabFace extends StatelessWidget {
  final IconData icon;

  const GlassFabFace({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1FA98A), AppColors.primary],
        ),
      ),
      child: Icon(icon, size: 26, color: Colors.white),
    );
  }
}

class _ActionRow<T> extends StatelessWidget {
  final GlassFabAction<T> action;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _ActionRow({super.key, required this.action, required this.animation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
        child: Material(
          color: Colors.white,
          elevation: 4,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: GlassFabMenu._rowHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 16, 7),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(action.icon, size: 20, color: action.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryNavy),
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

/// Thin arc with two dots, linking the close button to the action icons.
class _ConnectorPainter extends CustomPainter {
  final Rect fabRect;
  final double topRowY;

  const _ConnectorPainter({required this.fabRect, required this.topRowY});

  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(fabRect.right - 6, fabRect.top + 8);
    final end = Offset(fabRect.right, topRowY);
    final control = Offset(fabRect.right + 26, (start.dy + end.dy) / 2);
    Offset at(double t) {
      final u = 1 - t;
      return start * (u * u) + control * (2 * u * t) + end * (t * t);
    }

    final line = Paint()
      ..color = const Color(0xFF14B8A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy),
      line,
    );
    final dot = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = const Color(0xFF14B8A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final t in const [0.5, 1.0]) {
      canvas.drawCircle(at(t), 4, dot);
      canvas.drawCircle(at(t), 4, ring);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      fabRect != oldDelegate.fabRect || topRowY != oldDelegate.topRowY;
}
