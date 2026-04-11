import 'package:alice/alice.dart';
import 'package:alice/model/alice_configuration.dart';
import 'package:flutter/material.dart';

class AliceService {
  AliceService._();
  static final AliceService instance = AliceService._();

  final navigatorKey = GlobalKey<NavigatorState>();

  late final Alice alice = Alice(
    configuration: AliceConfiguration(
      navigatorKey: navigatorKey,
      showNotification: false,
      showInspectorOnShake: false,
    ),
  );

  void showInspector() => alice.showInspector();
}
