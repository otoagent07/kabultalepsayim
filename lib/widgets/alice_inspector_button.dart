import 'package:flutter/material.dart';
import '../services/alice_service.dart';
import '../services/storage_service.dart';

class AliceInspectorButton extends StatelessWidget {
  const AliceInspectorButton({super.key});

  static const _allowedUser = 'mehmet@rmosyazilim.com';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: StorageService.getUsername(),
      builder: (context, snapshot) {
        if (snapshot.data?.toLowerCase() != _allowedUser) {
          return const SizedBox.shrink();
        }
        return IconButton(
          icon: const Icon(Icons.info_outline),
          tooltip: 'HTTP İstekleri',
          onPressed: () => AliceService.instance.showInspector(),
        );
      },
    );
  }
}
