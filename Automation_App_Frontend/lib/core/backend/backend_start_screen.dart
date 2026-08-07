import 'package:flutter/material.dart';

/// Zwischenbild, solange der lokale Dienst hochfährt.
///
/// Steht oberhalb der eigentlichen Anwendung und bringt deshalb eine eigene
/// [MaterialApp] mit — zu diesem Zeitpunkt gibt es weder Theme noch Router.
class BackendStartScreen extends StatelessWidget {
  const BackendStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 24),
              Text('Anwendung wird gestartet …'),
            ],
          ),
        ),
      ),
    );
  }
}
