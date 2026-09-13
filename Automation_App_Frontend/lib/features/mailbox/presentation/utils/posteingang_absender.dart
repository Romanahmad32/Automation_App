import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';

/// Der Anzeigename eines Absenders: der Klarname, wenn die Mail einen trägt,
/// sonst die reine Adresse, sonst der rohe Absender-Rückfall des Servers.
///
/// Über benannte Parameter statt eines festen Typs, damit sowohl die Zeile
/// (`PosteingangEintrag`) als auch das Detail (`PosteingangInhalt`, eigene
/// Felder) dieselbe Regel verwenden — siehe [posteingangEintragAbsender].
String posteingangAbsenderName({
  String? absenderName,
  String? absenderAdresse,
  String absender = '',
}) {
  final name = (absenderName ?? '').trim();
  if (name.isNotEmpty) return name;
  final adresse = (absenderAdresse ?? '').trim();
  if (adresse.isNotEmpty) return adresse;
  final rueckfall = absender.trim();
  return rueckfall.isEmpty ? 'Unbekannter Absender' : rueckfall;
}

/// Bequemlichkeitsfassung für eine Posteingangszeile.
String posteingangEintragAbsender(PosteingangEintrag eintrag) =>
    posteingangAbsenderName(
      absenderName: eintrag.absenderName,
      absenderAdresse: eintrag.absenderAdresse,
      absender: eintrag.absender,
    );
