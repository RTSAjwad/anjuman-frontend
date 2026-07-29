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
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.template.name);
    _frontController =
        TextEditingController(text: widget.template.frontPattern);
    _backController = TextEditingController(text: widget.template.backPattern);
    _nameController.addListener(_notifyChange);
    _frontController.addListener(_notifyChange);
    _backController.addListener(_notifyChange);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialized = true;
    });
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
          TextArea(
            controller: _frontController,
            placeholder: const Text('e.g. {{Front}}'),
            initialValue: '',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          const Text('Back pattern', style: TextStyle(fontSize: 13)).semiBold(),
          const SizedBox(height: 6),
          TextArea(
            controller: _backController,
            placeholder: const Text('e.g. {{Back}}'),
            initialValue: '',
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
