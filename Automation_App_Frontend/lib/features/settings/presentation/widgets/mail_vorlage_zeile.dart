import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:flutter/material.dart';

/// Eine Vorlage in der Verwaltung: Name, darunter der Betreff, rechts Ändern
/// und Entfernen (§4.7).
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
    final betreff = vorlage.betreff.trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(vorlage.name),
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
    );
  }
}
