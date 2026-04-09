import 'dart:convert';
import 'package:flutter/material.dart';

class AppDialogs {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = 'Vazgeç',
    String confirmText = 'Evet',
    bool destructive = false,
    IconData icon = Icons.help_outline,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final color = destructive ? Colors.red : Theme.of(context).colorScheme.primary;
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? Colors.red : null,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
    return res == true;
  }

  static Future<bool> requestPreview(
    BuildContext context, {
    required String title,
    required String curlPreview,
    required Map<String, dynamic> jsonBody,
    List<String> mappingLines = const [],
    String? note,
    String cancelText = 'İptal',
    String confirmText = 'Gönder',
  }) async {
    const encoder = JsonEncoder.withIndent('  ');
    final pretty = encoder.convert(jsonBody);

    final res = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Widget sectionTitle(String t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
            );

        Widget mono(String t) => SelectableText(
              t,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            );

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.send_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionTitle('CURL PREVIEW'),
                  mono(curlPreview),
                  const SizedBox(height: 14),
                  sectionTitle('JSON BODY'),
                  mono(pretty),
                  if (note != null && note.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      note,
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (mappingLines.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    sectionTitle('EŞLEME DETAYI'),
                    ...mappingLines.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $t'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return res == true;
  }
}

