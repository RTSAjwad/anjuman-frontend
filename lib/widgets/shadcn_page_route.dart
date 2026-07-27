import 'package:flutter/material.dart';

/// A no-animation page route for shadcn navigation.
/// Use instead of [MaterialPageRoute] for instant transitions.
class ShadcnPageRoute<T> extends PageRouteBuilder<T> {
  ShadcnPageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              child,
        );
}
