import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/features/settings/presentation/widgets/anredebausteine_sektion.dart';
import 'package:automation_app/features/settings/presentation/widgets/grussformeln_sektion.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_vorlagen_sektion.dart';
import 'package:flutter/material.dart';

/// Die drei Bestände, aus denen eine Mail entsteht — **ein** Werkzeugkasten
/// unter gemeinsamen Reitern: Textvorlagen, Anreden, Zusatzgrüße (§4.7, §7.1,
/// zusammengeführt am 06.09.2026).
///
/// **Der Mangel, den das behebt:** Sie standen als drei gleichartige Karten
/// unverbunden untereinander, neben der Postfach-Signatur. Dass sie zusammen
/// den Werkzeugkasten des Versanddialogs bilden — die Anrede steht *in* der
/// Vorlage, der Gruß ebenso —, sah man ihnen nicht an; nebeneinander gelesen
/// wirkten sie wie drei Einstellungen, die nichts miteinander zu tun haben.
///
/// Reiter und keine drei Karten: Gepflegt wird immer nur einer der Bestände,
/// und alle drei gleichzeitig zu zeigen kostet die Höhe von drei Listen für
/// eine Aufgabe, die eine ist.
class MailBausteineSektion extends StatefulWidget {
  const MailBausteineSektion({super.key});

  @override
  State<MailBausteineSektion> createState() => _MailBausteineSektionState();
}

/// Einer der drei Reiter des Werkzeugkastens. Die Reihenfolge ist die, in der
/// die Stücke in der Mail stehen: erst die Vorlage, darin die Anrede, darunter
/// der Gruß.
enum MailBaustein {
  vorlagen('Textvorlagen', Icons.article_outlined),
  anreden('Anreden', Icons.record_voice_over_outlined),
  gruesse('Zusatzgrüße', Icons.waving_hand_outlined);

  final String bezeichnung;
  final IconData symbol;

  const MailBaustein(this.bezeichnung, this.symbol);

  /// Was der Reiter beantwortet — der Satz, der über seiner Liste steht.
  String get erklaerung => switch (this) {
    MailBaustein.vorlagen => MailVorlagenSektion.erklaerung,
    MailBaustein.anreden => AnredebausteineSektion.erklaerung,
    MailBaustein.gruesse => GrussformelnSektion.erklaerung,
  };
}

class _MailBausteineSektionState extends State<MailBausteineSektion> {
  MailBaustein _reiter = MailBaustein.vorlagen;

  Widget _inhalt() => switch (_reiter) {
    MailBaustein.vorlagen => const MailVorlagenSektion(),
    MailBaustein.anreden => const AnredebausteineSektion(),
    MailBaustein.gruesse => const GrussformelnSektion(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FormSection(
      icon: Icons.handyman_outlined,
      title: 'Mail-Vorlagen',
      subtitle:
          'Woraus der Versanddialog eine Mail baut: die Textvorlage, die '
          'Anrede darin und der Zusatzgruß darunter.',
      children: [
        SegmentedButton<MailBaustein>(
          segments: [
            for (final baustein in MailBaustein.values)
              ButtonSegment<MailBaustein>(
                value: baustein,
                label: Text(baustein.bezeichnung),
                icon: Icon(baustein.symbol, size: 18),
              ),
          ],
          selected: {_reiter},
          onSelectionChanged: (wahl) => setState(() => _reiter = wahl.first),
        ),
        Text(
          _reiter.erklaerung,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _inhalt(),
      ],
    );
  }
}
