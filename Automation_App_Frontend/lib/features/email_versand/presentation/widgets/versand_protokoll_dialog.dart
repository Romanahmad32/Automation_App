import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart';
import 'package:automation_app/features/email_versand/presentation/widgets/versand_eintrag_zeile.dart';
import 'package:flutter/material.dart';

/// Alles, was zu einem Vorgang hinausgegangen ist (§4.7) — der jüngste
/// Versand zuerst.
///
/// Ein Vorgang kann mehrere Mails haben: der Mandant nachträglich, ein
/// Korrekturschreiben, eine Nachfrage an die Versicherung. Die Übersicht zeigt
/// nur die letzte; hier steht die ganze Reihe mit Betreff, Anhängen und dem
/// Hinweis, wo die Mail selbst nachzusehen ist.
class VersandProtokollDialog extends StatefulWidget {
  final String referenz;

  const VersandProtokollDialog({super.key, required this.referenz});

  static Future<void> zeigen(BuildContext context, String referenz) {
    return showDialog<void>(
      context: context,
      builder: (_) => VersandProtokollDialog(referenz: referenz),
    );
  }

  @override
  State<VersandProtokollDialog> createState() => _VersandProtokollDialogState();
}

class _VersandProtokollDialogState extends State<VersandProtokollDialog> {
  List<VersandEintrag>? _eintraege;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    try {
      final geladen = await getIt<EmailVersandRepository>()
          .ladeVersandProtokoll(widget.referenz);
      if (mounted) setState(() => _eintraege = geladen);
    } catch (e) {
      // ausnahmeText statt '$e': Die Datenquelle übersetzt den Serverfehler
      // bereits ins Deutsche, das vorangestellte „Exception:" sähe davor nur
      // nach Defekt aus.
      if (mounted) setState(() => _fehler = ausnahmeText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('Versand zu ${widget.referenz}'),
      content: SizedBox(width: 520, child: _inhalt(theme)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }

  Widget _inhalt(ThemeData theme) {
    if (_fehler case final grund?) {
      return Text('Das Protokoll ließ sich nicht laden: $grund');
    }

    final eintraege = _eintraege;
    if (eintraege == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (eintraege.isEmpty) {
      return Text(
        'Zu diesem Vorgang hat die App noch nichts versendet. Was außerhalb '
        'der App hinausging, weiß sie nicht.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final eintrag in eintraege) ...[
            VersandEintragZeile(eintrag: eintrag, ausfuehrlich: true),
            if (eintrag != eintraege.last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}
