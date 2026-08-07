import 'dart:io';

import 'package:flutter/material.dart';

/// Zeigt, warum die Anwendung nicht starten konnte.
///
/// Ohne diesen Bildschirm bliebe im Fehlerfall ein leeres weißes Fenster — der
/// Anwender hätte keinen Anhaltspunkt und nichts, was er weitergeben könnte.
/// Die Meldung ist deshalb markierbar.
class BackendStartFehlerScreen extends StatelessWidget {
  const BackendStartFehlerScreen({
    required this.meldung,
    required this.onErneutVersuchen,
    super.key,
  });

  final String meldung;
  final VoidCallback onErneutVersuchen;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, size: 32),
                      const SizedBox(width: 12),
                      Text(
                        'Die Anwendung konnte nicht starten',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        meldung,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => exit(1),
                        child: const Text('Beenden'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onErneutVersuchen,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
