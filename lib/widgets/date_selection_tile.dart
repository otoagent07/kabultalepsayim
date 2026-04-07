import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'selection_tile.dart';

class DateSelectionTile extends StatelessWidget {
  const DateSelectionTile({
    super.key,
    required this.onTap,
    required this.selectedDate,
    this.label = 'Tarih',
    this.iconColor = Colors.blue,
    this.labelFontSize = 24,
    this.valueFontSize = 20,
    this.iconSize = 40,
  });

  final VoidCallback onTap;
  final DateTime selectedDate;
  final String label;
  final Color iconColor;
  final double labelFontSize;
  final double valueFontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SelectionTile(
      onTap: onTap,
      icon: Icons.calendar_today,
      iconColor: iconColor,
      label: label,
      value: DateFormat('dd.MM.yyyy').format(selectedDate),
      valueColor: Colors.grey[700],
      labelFontSize: labelFontSize,
      valueFontSize: valueFontSize,
      iconSize: iconSize,
    );
  }
}

