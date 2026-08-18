import 'package:shadcn_flutter/shadcn_flutter.dart';

/// A searchable dropdown styled to match shadcn's [Select] component.
///
/// Displays a label above the select and supports async data loading
/// with search filtering, loading, and empty states.
class ShadcnSearchDropdown<T> extends StatelessWidget {
  final String? label;
  final String hintText;
  final Future<List<T>> Function(String query) loader;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final void Function(T?) onChanged;
  final T? value;

  const ShadcnSearchDropdown({
    super.key,
    this.label,
    required this.hintText,
    required this.loader,
    required this.itemBuilder,
    required this.onChanged,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: const TextStyle(fontSize: 13)).semiBold(),
          const SizedBox(height: 6),
        ],
        Select<T>(
          value: value,
          placeholder: Text(hintText),
          onChanged: onChanged,
          itemBuilder: itemBuilder,
          popup: SelectPopup.builder(
            searchPlaceholder: Text('Search ${label ?? hintText}'),
            emptyBuilder: (context) {
              return Center(
                child: Text(
                  'No results found',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.mutedForeground,
                    fontSize: 14,
                  ),
                ),
              );
            },
            loadingBuilder: (context) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
            builder: (context, searchQuery) async {
              final items = await loader(searchQuery ?? '');

              if (items.isEmpty) {
                return const SelectItemBuilder(
                  builder: _emptyBuilder,
                  childCount: 0,
                );
              }

              return SelectItemBuilder(
                childCount: items.length,
                builder: (context, index) {
                  final item = items[index];
                  return SelectItemButton(
                    value: item,
                    child: itemBuilder(context, item),
                  );
                },
              );
            },
          ).call,
        ),
      ],
    );
  }
}

Widget _emptyBuilder(BuildContext context, int index) =>
    const SizedBox.shrink();
