import 'package:flutter/material.dart';

class SelectionTile extends StatelessWidget {
  const SelectionTile({
    super.key,
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.cardTint,
    this.kodLine,
    this.valueColor,
    this.valueWeight,
    this.kodColor,
    this.margin = const EdgeInsets.all(3),
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    this.labelFontSize = 24,
    this.valueFontSize = 20,
    this.kodFontSize = 16,
    this.iconSize = 40,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color? cardTint;
  final String label;
  final String value;
  final String? kodLine;
  final Color? valueColor;
  final FontWeight? valueWeight;
  final Color? kodColor;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double labelFontSize;
  final double valueFontSize;
  final double kodFontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardTint,
      margin: margin,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: iconSize),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        color: valueColor ?? Colors.grey[700],
                        fontWeight: valueWeight ?? FontWeight.normal,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (kodLine != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        kodLine!,
                        style: TextStyle(
                          fontSize: kodFontSize,
                          color: kodColor ?? Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

