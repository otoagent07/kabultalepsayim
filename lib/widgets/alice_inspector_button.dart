import 'package:flutter/material.dart';
import '../services/alice_service.dart';
import '../services/storage_service.dart';

class AliceInspectorButton extends StatelessWidget {
  const AliceInspectorButton({super.key});

  static const String _aliceInspectorBypassUsername = 'mehmet@rmosyazilim.com';

  static void _showPasswordDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _PasswordDialog(),
    );
  }

  static Future<void> _onPressed(BuildContext context) async {
    final username = (await StorageService.getUsername())?.trim() ?? '';
    if (!context.mounted) return;
    if (username.toLowerCase() == _aliceInspectorBypassUsername) {
      AliceService.instance.showInspector();
    } else {
      _showPasswordDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'HTTP İstekleri',
      onPressed: () => _onPressed(context),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  static const String _password = '*3*';

  final _controller = TextEditingController();
  String _error = '';
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tryOpen(BuildContext ctx) {
    if (_submitted) return;
    if (_controller.text == _password) {
      _submitted = true;
      Navigator.of(ctx).pop();
      AliceService.instance.showInspector();
    } else {
      setState(() => _error = 'Şifre yanlış');
    }
  }

  @override
  Widget build(BuildContext context) {
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
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Şifre',
              errorText: _error.isEmpty ? null : _error,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (_error.isNotEmpty) setState(() => _error = '');
              if (value == _password) _tryOpen(context);
            },
            onSubmitted: (_) => _tryOpen(context),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => _tryOpen(context),
          child: const Text('Aç'),
        ),
      ],
    );
  }
}
