import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../config/breakpoints.dart';

typedef ResponsiveDialogBuilder = Widget Function(
  BuildContext context,
  Object? state,
);

/// Shows a dialog as a centered overlay on medium+ screens, or a bottom
/// drawer on compact screens.
///
/// The configuration is chosen at the time the dialog is opened and does not
/// change if the window is resized while open.
///
/// If [state] is provided, it is passed to [builder] so the caller can
/// preserve mutable state across future breakpoint-aware reopen cycles
/// (not yet implemented).
void showResponsiveDialog(
  BuildContext context, {
  required ResponsiveDialogBuilder builder,
  Object? state,
}) {
  final width = MediaQuery.of(context).size.width;
  if (width < Breakpoints.medium) {
    showOverlay(
      context,
      DrawerConfiguration(
        position: OverlayPosition.bottom,
        expands: false,
        builder: (ctx) => builder(ctx, state),
      ),
    );
  } else {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => builder(ctx, state),
      ),
    );
  }
}

/// Safely closes the overlay, deferring to a post-frame callback to avoid
/// disposing the overlay Navigator while it's locked during the frame cycle.
/// Always call this instead of [closeOverlay] directly when closing from an
/// async handler (after an await).
void safeCloseOverlay(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    closeOverlay(context);
  });
}
