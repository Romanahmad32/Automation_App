import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:automation_app/features/email_versand/domain/services/mail_vorlage_zustand.dart';
import 'package:flutter/material.dart';

/// Eine Vorlage in der Verwaltung: Name mit **Zustandsabzeichen**, darunter der
/// Betreff, rechts Ändern und Entfernen (§4.7).
///
/// Das Abzeichen ist die Auskunft, die der Liste vorher fehlte: Name und
/// Betreff hat der Anwalt selbst hingeschrieben, ob die Vorlage einsatzbereit
/// ist, nicht. Gerechnet wird sie in [MailVorlageZustand].
class MailVorlageZeile extends StatelessWidget {
  final MailVorlage vorlage;
  final VoidCallback onBearbeiten;
  final VoidCallback onEntfernen;

  const MailVorlageZeile({
    super.key,
    required this.vorlage,
    required this.onBearbeiten,
    required this.onEntfernen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final betreff = vorlage.betreff.trim();
    final zustand = MailVorlageZustand.fuer(vorlage);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Row(
        spacing: 8,
        children: [
          Flexible(child: Text(vorlage.name, overflow: TextOverflow.ellipsis)),
          MailVorlageAbzeichen(zustand: zustand),
        ],
      ),
      subtitle: Text(
        betreff.isEmpty ? 'Ohne Betreffzeile' : betreff,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Vorlage ändern',
            onPressed: onBearbeiten,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Vorlage entfernen',
            onPressed: onEntfernen,
          ),
        ],
      ),
      onTap: onBearbeiten,
      // Ohne diese Zeile schneidet die Kachel den zweizeiligen Titel bei
      // schmaler Spalte ab, statt ihn umbrechen zu lassen.
      isThreeLine: false,
      titleTextStyle: theme.textTheme.bodyLarge,
    );
  }
}

/// Das Zustandsabzeichen einer Vorlage — ruhig, wenn sie fertig ist, im
/// Hinweiston der App, wenn noch etwas offen ist (kein Alarmrot: eine Vorlage
/// im Werden ist kein Fehler).
class MailVorlageAbzeichen extends StatelessWidget {
  final MailVorlageZustand zustand;

  const MailVorlageAbzeichen({super.key, required this.zustand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ton = zustand.inOrdnung
        ? theme.colorScheme.outline
        : theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ton.withValues(alpha: 0.6)),
      ),
      child: Text(
        zustand.text,
        style: theme.textTheme.labelSmall?.copyWith(color: ton),
      ),
    );
  }
}
