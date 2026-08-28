import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

/// Nimmt Dateien entgegen, die aus dem Explorer hereingezogen werden, und legt
/// über den [child] einen Schleier, solange etwas darüber schwebt.
///
/// Der Grund steht in der Kanzlei: Anhänge werden dort mit der Maus
/// zusammengesucht, nicht über einen Dateiauswahldialog. Ein Knopf allein
/// zwingt zu einem Weg, den niemand geht.
///
/// Ordner werden **nicht** angenommen — ein Anhang ist eine Datei. Wird nur
/// ein Ordner abgelegt, meldet sich [onOrdnerAbgelehnt]; ohne diese Meldung
/// sähe das Ablegen aus wie ein verschluckter Griff.
///
/// Kommt **gar nichts** an, meldet sich [onNichtsErkannt]. Das ist kein
/// theoretischer Fall: Windows reicht beim Ziehen aus dem Explorer Dateipfade
/// durch (`CF_HDROP`), Outlook seine Anhänge dagegen als virtuelle Dateien
/// (`CFSTR_FILEDESCRIPTORW`), die `desktop_drop` nicht liest. Ein Anhang, aus
/// Outlook hereingezogen, kommt hier deshalb als leeres Ablegen an — und darf
/// nicht mit „Ordner lassen sich nicht anhängen" beantwortet werden.
class DateiAblageBereich extends StatefulWidget {
  /// Die abgelegten Dateien, Ordner bereits aussortiert. Nie leer.
  final ValueChanged<List<String>> onDateien;

  /// Es wurde etwas abgelegt, aber keine einzige Datei war dabei — Ordner.
  final VoidCallback? onOrdnerAbgelehnt;

  /// Es wurde etwas abgelegt, das Windows gar nicht als Datei durchgereicht
  /// hat. Der übliche Fall: ein Anhang aus einer Outlook-Nachricht.
  final VoidCallback? onNichtsErkannt;

  /// Steht im Schleier — sagt, was das Ablegen bewirkt.
  final String hinweis;

  final bool aktiv;

  final Widget child;

  const DateiAblageBereich({
    super.key,
    required this.onDateien,
    required this.child,
    this.onOrdnerAbgelehnt,
    this.onNichtsErkannt,
    this.hinweis = 'Dateien hier ablegen',
    this.aktiv = true,
  });

  /// Sortiert aus, was keine Datei ist. Windows liefert beim Ziehen eines
  /// Ordners dessen Pfad wie jeden anderen — ohne diese Prüfung landete er als
  /// Anhang in der Liste und schlüge erst beim Senden fehl.
  static List<String> nurDateien(Iterable<String> pfade) => pfade
      .where((pfad) => pfad.isNotEmpty && FileSystemEntity.isFileSync(pfad))
      .toList();

  @override
  State<DateiAblageBereich> createState() => _DateiAblageBereichState();
}

class _DateiAblageBereichState extends State<DateiAblageBereich> {
  bool _schwebtDarueber = false;

  void _abgelegt(DropDoneDetails details) {
    setState(() => _schwebtDarueber = false);

    // Leer heisst: Es kam nichts an, was Windows als Datei durchreicht — der
    // Griff aus Outlook. Eine Liste, aus der nur die Ordner herausgefallen
    // sind, ist etwas anderes und bekommt eine andere Antwort.
    if (details.files.isEmpty) {
      widget.onNichtsErkannt?.call();
      return;
    }

    final dateien = DateiAblageBereich.nurDateien(
      details.files.map((abgelegt) => abgelegt.path),
    );

    if (dateien.isEmpty) {
      widget.onOrdnerAbgelehnt?.call();
      return;
    }

    widget.onDateien(dateien);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropTarget(
      enable: widget.aktiv,
      onDragEntered: (_) => setState(() => _schwebtDarueber = true),
      onDragExited: (_) => setState(() => _schwebtDarueber = false),
      onDragDone: _abgelegt,
      child: Stack(
        children: [
          widget.child,
          if (_schwebtDarueber)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.85,
                    ),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 40,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.hinweis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
