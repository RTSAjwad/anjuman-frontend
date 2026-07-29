/// Material Design 3 responsive breakpoints.
///
/// Each constant represents the minimum width at which a layout range begins.
/// Ranges: Compact (0–599), Medium (600–839), Expanded (840–1199),
/// Large (1200–1599), Extra-large (1600+).
class Breakpoints {
  Breakpoints._();

  /// Enter Medium range: dual-pane layouts (600px+)
  static const double medium = 600;

  /// Enter Expanded range: side navigation rail (840px+)
  static const double expanded = 840;

  /// Enter Large range: wider content, larger list panes (1200px+)
  static const double large = 1200;

  /// Enter Extra-large range (1600px+)
  static const double extraLarge = 1600;
}
