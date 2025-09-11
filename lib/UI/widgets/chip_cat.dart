import 'package:flutter/material.dart';

class ChipCat extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ChipCat({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      side: BorderSide(color: scheme.outlineVariant),
      showCheckmark: selected,
    );
  }
}
