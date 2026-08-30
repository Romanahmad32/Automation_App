import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:equatable/equatable.dart';

/// Ein Ausschnitt des Mandantenregisters samt der beiden Zahlen, die ihn
/// einordnen. In der Kanzlei stehen dort tausende Mandanten; die Liste holt
/// sie deshalb seitenweise nach (`GET /api/Mandanten/seite`).
///
/// [gefiltert] ist die Zahl der Treffer im **ganzen** Bestand, nicht in diesem
/// Ausschnitt: Erst daran sieht die Liste, ob es noch etwas nachzuladen gibt.
/// Aus „die Seite war voll" allein ließe sich das nicht schließen — bei genau
/// 50 Treffern wäre der Schluss falsch.
class MandantenSeite extends Equatable {
  /// Die Mandanten dieses Ausschnitts.
  final List<Mandant> mandanten;

  /// Wie viele Mandanten das Register insgesamt führt (ohne Suche).
  final int gesamt;

  /// Wie viele davon die Suche trifft. Ohne Suche gleich [gesamt].
  final int gefiltert;

  const MandantenSeite({
    this.mandanten = const [],
    this.gesamt = 0,
    this.gefiltert = 0,
  });

  factory MandantenSeite.fromJson(Map<String, dynamic> json) {
    final mandanten = json['mandanten'];
    return MandantenSeite(
      mandanten: mandanten is List
          ? [
              for (final eintrag in mandanten.whereType<Map<String, dynamic>>())
                Mandant.fromJson(eintrag),
            ]
          : const [],
      gesamt: json['gesamt'] as int? ?? 0,
      gefiltert: json['gefiltert'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [mandanten, gesamt, gefiltert];
}
