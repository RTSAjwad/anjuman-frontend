import 'package:flutter/material.dart';

/// A sortable column header that fills its parent width.
/// The entire cell area is tappable.
class SortableHeader extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const SortableHeader({
    super.key,
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isActive)
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

/// Sort state for a table — stores which field is active and direction.
/// Call [sort] to get a sorted copy of the list.
class TableSort<T, F extends Enum> {
  F field;
  bool ascending;

  TableSort(this.field, this.ascending);

  void toggle(F f) {
    if (field == f) {
      ascending = !ascending;
    } else {
      field = f;
      ascending = true;
    }
  }

  List<T> sort(List<T> items, Comparable Function(T item, F field) key) {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final result = key(a, field).compareTo(key(b, field));
      return ascending ? result : -result;
    });
    return sorted;
  }
}
