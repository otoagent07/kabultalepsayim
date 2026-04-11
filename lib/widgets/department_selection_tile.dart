import 'package:flutter/material.dart';

import 'selection_tile.dart';

class DepartmentSelectionTile extends StatelessWidget {
  const DepartmentSelectionTile({
    super.key,
    required this.onTap,
    required this.departmentName,
    this.departmentKod,
    this.efutadbIdText,
    this.subeText,
    this.label = 'Departman',
    this.selectedColor = Colors.blue,
    this.unselectedColor = Colors.grey,
    this.labelFontSize = 24,
    this.valueFontSize = 20,
    this.kodFontSize = 16,
    this.iconSize = 40,
  });

  final VoidCallback onTap;
  final String? departmentName;
  final String? departmentKod;
  final String? efutadbIdText;
  final String? subeText;
  final String label;
  final Color selectedColor;
  final Color unselectedColor;
  final double labelFontSize;
  final double valueFontSize;
  final double kodFontSize;
  final double iconSize;

  bool get _isSelected => (departmentName != null && departmentName!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final iconColor = _isSelected ? selectedColor : unselectedColor;
    final kod = departmentKod;
    final efatLine = efutadbIdText;
    final subeLine = (subeText == null || subeText!.isEmpty) ? null : 'Şube: $subeText';
    final kodLine = (kod == null || kod.isEmpty)
        ? null
        : [
            'Kod: $kod',
            if (subeLine != null) subeLine,
            if (efatLine != null && efatLine.isNotEmpty) efatLine,
          ].join('   ');
    return SelectionTile(
      onTap: onTap,
      icon: Icons.business,
      iconColor: iconColor,
      label: label,
      value: departmentName ?? 'Seçiniz',
      kodLine: kodLine,
      valueColor: Colors.grey[700],
      valueWeight: FontWeight.w600,
      kodColor: Colors.grey[600],
      labelFontSize: labelFontSize,
      valueFontSize: valueFontSize,
      kodFontSize: kodFontSize,
      iconSize: iconSize,
    );
  }
}

