import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'drawer_context.dart';

/// An [AppBar] that shows a menu button on narrow screens to open the
/// navigation drawer. Uses [DrawerContext] to get the drawer callback.
class NarrowAppBar extends StatelessWidget {
  final Widget title;
  final List<Widget> trailing;
  final Widget? subtitle;
  final List<Widget> leading;

  const NarrowAppBar({
    super.key,
    required this.title,
    this.trailing = const [],
    this.subtitle,
    this.leading = const [],
  });

  @override
  Widget build(BuildContext context) {
    final openDrawer = DrawerContext.of(context);

    return AppBar(
      leading: [
        if (openDrawer != null)
          IconButton.outline(
            icon: const Icon(LucideIcons.menu, size: 20),
            onPressed: openDrawer,
          ),
        ...leading,
      ],
      title: title,
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
