import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../config/breakpoints.dart';

/// Shows a dialog as a centered overlay on medium+ screens, or a bottom
/// drawer on compact screens.
void showResponsiveDialog(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final width = MediaQuery.of(context).size.width;
  if (width < Breakpoints.medium) {
    showOverlay(
      context,
      DrawerConfiguration(
        position: OverlayPosition.bottom,
        expands: false,
        builder: (ctx) => builder(ctx),
      ),
    );
  } else {
    showOverlay(
      context,
      DialogConfiguration(
        builder: (ctx) => builder(ctx),
      ),
    );
  }
}
