import 'package:flutter/material.dart';
import '../services/alice_service.dart';

class AliceInspectorButton extends StatelessWidget {
  const AliceInspectorButton({super.key});

  static const String _inspectorPassword = '*3*';

  static void _showPasswordDialog(BuildContext context) {
    final passwordController = TextEditingController();
    var wrong = '';

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('HTTP istekleri'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alice denetçisini açmak için şifreyi girin.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    errorText: wrong.isEmpty ? null : wrong,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (wrong.isNotEmpty) {
                      setDialogState(() => wrong = '');
                    }
                  },
                  onSubmitted: (_) {
                    if (passwordController.text == _inspectorPassword) {
                      Navigator.of(ctx).pop();
                      AliceService.instance.showInspector();
                    } else {
                      setDialogState(() => wrong = 'Şifre yanlış');
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () {
                  if (passwordController.text == _inspectorPassword) {
                    Navigator.of(ctx).pop();
                    AliceService.instance.showInspector();
                  } else {
                    setDialogState(() => wrong = 'Şifre yanlış');
                  }
                },
                child: const Text('Aç'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(passwordController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'HTTP İstekleri',
      onPressed: () => _showPasswordDialog(context),
    );
  }
}
