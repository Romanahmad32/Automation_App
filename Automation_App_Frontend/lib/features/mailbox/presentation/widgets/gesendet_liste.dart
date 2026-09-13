import 'package:automation_app/features/email_versand/domain/entities/versand_eintrag.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_tagesgruppen.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/gesendet_zeile.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_gruppen_kopf.dart';
import 'package:flutter/material.dart';

/// Die Liste des Bereichs „Gesendet" (§4.3): dieselben Tagesgruppen wie im
/// Posteingang (`PosteingangGruppenKopf`, `PosteingangTagesgruppe.tagVon`),
/// nur mit Versänden statt eingegangenen Nachrichten. Die Gruppierung selbst
/// steht hier und nicht in `posteingang_tagesgruppen.dart`: Die dortige
/// Funktion arbeitet auf `PosteingangEintrag`; sie für zwei Typen generisch zu
/// machen, hieße, eine dreizeilige Schleife hinter einem Typparameter zu
/// verstecken.
///
/// Nimmt ihre Daten als Konstruktorparameter entgegen und holt sich nichts aus
/// dem Kontext — damit bleibt sie ohne DI testbar.
class GesendetListe extends StatelessWidget {
  const GesendetListe({
    super.key,
    required this.eintraege,
    this.zeichen = const {},
  });

  final List<VersandEintrag> eintraege;

  /// Vorgangsreferenz (kleingeschrieben) → Zeichen, für die Pille an der
  /// Zeile. Kommt von außen, weil die Liste den Vorgangsbestand nicht kennt.
  final Map<String, String> zeichen;

  @override
  Widget build(BuildContext context) {
    if (eintraege.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Noch nichts aus der App versendet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final items = <Object>[];
    DateTime? letzterTag;
    for (final eintrag in eintraege) {
      final tag = PosteingangTagesgruppe.tagVon(eintrag.gesendetAm);
      if (tag != letzterTag) {
        items.add(tag);
        letzterTag = tag;
      }
      items.add(eintrag);
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DateTime) return PosteingangGruppenKopf(tag: item);
        final eintrag = item as VersandEintrag;
        return GesendetZeile(
          eintrag: eintrag,
          zeichen: zeichen[eintrag.vorgangReferenz.trim().toLowerCase()],
        );
      },
    );
  }
}
