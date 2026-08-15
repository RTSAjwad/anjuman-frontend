import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders Anki card HTML (front/back) in a system webview where supported,
/// falling back to plain-text for platforms without webview support.
///
/// The webview fills all available space and scrolls its content internally.
/// Content is wrapped in a minimal HTML skeleton that follows the app's
/// light/dark theme.
class CardHtmlView extends StatefulWidget {
  final String html;

  const CardHtmlView({super.key, required this.html});

  @override
  State<CardHtmlView> createState() => _CardHtmlViewState();
}

class _CardHtmlViewState extends State<CardHtmlView> {
  WebViewController? _controller;

  @override
  void didUpdateWidget(covariant CardHtmlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _reload();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recreate on theme change so the background/text colors follow it.
    _reload();
  }

  void _reload() {
    if (!_supportsWebView) return;

    final isDark = _isDarkTheme;
    // ignore: avoid_print
    print('CardHtmlView._reload: isDark=$isDark, surface=${Theme.of(context).colorScheme.surface}');
    final html = _wrapHtml(widget.html, isDark);

    if (_controller == null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setBackgroundColor(isDark ? const Color(0xFF1A1A1A) : Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            // Card content is local HTML; block any external navigation.
            onNavigationRequest: (request) {
              if (request.isMainFrame && request.url == 'about:blank') {
                return NavigationDecision.navigate;
              }
              return NavigationDecision.prevent;
            },
          ),
        );
    } else {
      _controller!.setBackgroundColor(
          isDark ? const Color(0xFF1A1A1A) : Colors.white);
    }

    _controller!.loadHtmlString(html);
  }

  bool get _supportsWebView {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  /// Determines dark mode from the actual background color luminance, since
  /// shadcn's `ThemeData.brightness` is unreliable (reports light even when
  /// a dark color scheme is visually active).
  bool get _isDarkTheme {
    final surface = Theme.of(context).colorScheme.surface;
    return surface.computeLuminance() < 0.5;
  }

  static String _wrapHtml(String body, bool isDark) {
    final bg = isDark ? '#1a1a1a' : '#ffffff';
    final fg = isDark ? '#e5e5e5' : '#1a1a1a';
    return '''
<!DOCTYPE html>
<html style="background-color: $bg;">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background-color: $bg !important;
      color: $fg !important;
      font-size: 20px;
      line-height: 1.5;
      word-wrap: break-word;
      overflow-wrap: anywhere;
    }
    body { margin: 16px; }
    img { max-width: 100%; height: auto; }
    a { color: #3b82f6; }
  </style>
</head>
<body>$body</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_supportsWebView && _controller != null) {
      return WebViewWidget(controller: _controller!);
    }

    // Fallback: render rich HTML via flutter_html on web/desktop.
    final isDark = _isDarkTheme;
    final fg = isDark ? Colors.white : Colors.black;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Html(
        data: widget.html,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(20),
            fontWeight: FontWeight.w400,
            textAlign: TextAlign.center,
            color: fg,
          ),
        },
      ),
    );
  }
}
