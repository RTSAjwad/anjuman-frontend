import 'package:flutter/material.dart' show Brightness;
import 'package:flutter/painting.dart' show Colors;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart' as dark;
import 'package:re_highlight/styles/vs.dart' as light;
import 'package:shadcn_flutter/shadcn_flutter.dart';

class NoteTemplateEntry {
  final String name;
  final String frontPattern;
  final String backPattern;

  const NoteTemplateEntry({
    required this.name,
    required this.frontPattern,
    required this.backPattern,
  });
}

class TemplateDetailScreen extends StatefulWidget {
  final NoteTemplateEntry template;
  final void Function(NoteTemplateEntry updated)? onChanged;

  const TemplateDetailScreen({
    super.key,
    required this.template,
    this.onChanged,
  });

  @override
  State<TemplateDetailScreen> createState() => TemplateDetailScreenState();
}

class TemplateDetailScreenState extends State<TemplateDetailScreen> {
  late final TextEditingController _nameController;
  late final CodeLineEditingController _frontController;
  late final CodeLineEditingController _backController;
  final Highlight _highlighter = Highlight()..registerLanguage('xml', langXml);
  late final Map<String, TextStyle> _theme;
  bool _themeInitialized = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.template.name);
    _frontController = CodeLineEditingController(
      codeLines: CodeLines.fromText(widget.template.frontPattern),
      spanBuilder: _buildSpans,
    );
    _backController = CodeLineEditingController(
      codeLines: CodeLines.fromText(widget.template.backPattern),
      spanBuilder: _buildSpans,
    );
    _nameController.addListener(_notifyChange);
    _frontController.addListener(_notifyChange);
    _backController.addListener(_notifyChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialized = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_themeInitialized) {
      final colors = Theme.of(context).colorScheme;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final baseTheme = isDark ? dark.atomOneDarkTheme : light.vsTheme;
      _theme = Map<String, TextStyle>.from(baseTheme);
      _theme['root'] = TextStyle(
        color: colors.foreground,
        backgroundColor: Colors.transparent,
      );
      _themeInitialized = true;
    }
  }

  TextSpan _buildSpans({
    required BuildContext context,
    required int index,
    required CodeLine codeLine,
    required TextSpan textSpan,
    required TextStyle style,
  }) {
    final result = _highlighter.highlight(
      code: codeLine.text,
      language: 'xml',
    );
    final renderer = TextSpanRenderer(style, _theme);
    result?.render(renderer);
    return renderer.span ?? textSpan;
  }

  void _notifyChange() {
    if (!_initialized) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    widget.onChanged?.call(NoteTemplateEntry(
      name: name,
      frontPattern: _frontController.text.trim(),
      backPattern: _backController.text.trim(),
    ));
  }

  @override
  void dispose() {
    _nameController.removeListener(_notifyChange);
    _frontController.removeListener(_notifyChange);
    _backController.removeListener(_notifyChange);
    _nameController.dispose();
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Template name', style: TextStyle(fontSize: 13))
              .semiBold(),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            placeholder: const Text('e.g. Forward'),
            initialValue: _nameController.text,
          ),
          const SizedBox(height: 16),
          const Text('Front pattern', style: TextStyle(fontSize: 13))
              .semiBold(),
          const SizedBox(height: 6),
          _buildCodeEditor(colors, _frontController),
          const SizedBox(height: 16),
          const Text('Back pattern', style: TextStyle(fontSize: 13)).semiBold(),
          const SizedBox(height: 6),
          _buildCodeEditor(colors, _backController),
        ],
      ),
    );
  }

  Widget _buildCodeEditor(
      ColorScheme colors, CodeLineEditingController controller) {
    return OutlinedContainer(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: CodeEditor(
          controller: controller,
          style: CodeEditorStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            textColor: colors.foreground,
            backgroundColor: colors.background,
            cursorColor: colors.foreground,
            selectionColor: colors.primary.withAlpha(40),
            highlightColor: colors.primary.withAlpha(20),
          ),
          indicatorBuilder:
              (context, editingController, chunkController, notifier) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                  textStyle: TextStyle(
                    color: colors.mutedForeground,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                DefaultCodeChunkIndicator(
                  width: 16,
                  controller: chunkController,
                  notifier: notifier,
                ),
              ],
            );
          },
          chunkAnalyzer: const _HtmlChunkAnalyzer(),
        ),
      ),
    );
  }
}

/// Detects foldable regions for HTML/XML tags.
class _HtmlChunkAnalyzer implements CodeChunkAnalyzer {
  const _HtmlChunkAnalyzer();

  static final _tagRegex = RegExp(r'<(\w+)[^>]*>|</(\w+)>');

  @override
  List<CodeChunk> run(CodeLines codeLines) {
    final List<CodeChunk> chunks = [];
    final List<_TagEntry> stack = [];

    for (int i = 0; i < codeLines.length; i++) {
      final text = codeLines[i].text;
      final matches = _tagRegex.allMatches(text);
      for (final match in matches) {
        final openTag = match.group(1);
        final closeTag = match.group(2);
        if (openTag != null) {
          stack.add(_TagEntry(tag: openTag, line: i));
        } else if (closeTag != null) {
          for (int j = stack.length - 1; j >= 0; j--) {
            if (stack[j].tag == closeTag) {
              if (stack[j].line < i) {
                chunks.add(CodeChunk(stack[j].line, i));
              }
              stack.removeRange(j, stack.length);
              break;
            }
          }
        }
      }
    }

    chunks.sort((a, b) => a.index - b.index);
    return chunks;
  }
}

class _TagEntry {
  final String tag;
  final int line;

  const _TagEntry({required this.tag, required this.line});
}
