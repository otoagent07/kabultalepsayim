import 'package:flutter/material.dart';
import '../services/alice_service.dart';

class AliceInspectorButton extends StatelessWidget {
  const AliceInspectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: 'HTTP İstekleri',
      onPressed: () => AliceService.instance.showInspector(),
    );
  }
}
