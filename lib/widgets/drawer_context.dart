import 'package:flutter/material.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Provides a drawer open callback to descendants via [DrawerContext.of].
class DrawerContext extends InheritedWidget {
  final VoidCallback onOpenDrawer;

  const DrawerContext({
    super.key,
    required this.onOpenDrawer,
    required super.child,
  });

  static VoidCallback? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DrawerContext>()
        ?.onOpenDrawer;
  }

  @override
  bool updateShouldNotify(DrawerContext old) =>
      onOpenDrawer != old.onOpenDrawer;
}
