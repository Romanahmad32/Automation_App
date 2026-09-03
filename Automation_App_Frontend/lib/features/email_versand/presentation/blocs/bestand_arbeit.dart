import 'package:flutter_bloc/flutter_bloc.dart';

/// Der gemeinsame Rahmen der drei Mail-Bestände (§4.7): Vorlagen, Zusatzgrüße
/// und Anredeanfänge.
///
/// Alle drei tun beim Laden, Speichern und Entfernen dasselbe — Ladeanzeige
/// an, alte Meldung weg, Fehler im Klartext stehen lassen, Ladeanzeige aus —
/// und trugen es bis zum 03.09.2026 in drei Abschriften. Der Preis dafür war
/// nicht die Länge, sondern die Drift: `MailVorlagenCubit.laden` hatte den
/// Rumpf von `_neuLaden` nebenan schon kopiert, statt ihn zu rufen.
///
/// Was **nicht** hierher gehört: die Bestände selbst. Sie heissen verschieden
/// (`vorlagen`, `grussformeln`, `bausteine`), und ein gemeinsamer Name
/// `eintraege` machte aus drei lesbaren Zuständen einen generischen.
mixin BestandArbeit<S> on Cubit<S> {
  /// Der eigene Zustand mit gesetzter Ladeanzeige und Meldung — die eine
  /// Zeile, die jeder Bestand selbst beisteuert. [fehler] null räumt eine
  /// stehende Meldung weg; ein neuer Versuch soll sie loswerden können.
  S mitLadestand({required bool laedt, String? fehler});

  /// Führt [arbeit] im Rahmen aus und meldet, ob es geklappt hat — der Dialog
  /// schliesst sich nur dann.
  Future<bool> fuehreAus(Future<void> Function() arbeit) async {
    emit(mitLadestand(laedt: true));
    try {
      await arbeit();
      if (!isClosed) emit(mitLadestand(laedt: false));
      return true;
    } catch (fehler) {
      if (!isClosed) {
        emit(mitLadestand(laedt: false, fehler: klartext(fehler)));
      }
      return false;
    }
  }

  /// `Exception: …` ist der Präfix, den `toString()` davorsetzt; im Dialog
  /// stünde er vor jedem Satz, den das Backend über `backendFehlertext`
  /// geschickt hat.
  static String klartext(Object fehler) =>
      fehler.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
