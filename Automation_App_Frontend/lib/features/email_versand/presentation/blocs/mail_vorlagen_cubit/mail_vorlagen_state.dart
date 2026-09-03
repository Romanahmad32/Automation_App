import 'package:automation_app/features/email_versand/domain/entities/mail_vorlage.dart';
import 'package:equatable/equatable.dart';

/// Stand des Vorlagenbestands (§4.7). Ein Zustand statt einer Zustandsfamilie:
/// Die Liste bleibt beim Laden und nach einem Fehler stehen — sie einzuziehen
/// hiesse, dem Anwalt mitten im Pflegen die Übersicht wegzunehmen.
class MailVorlagenState extends Equatable {
  final List<MailVorlage> vorlagen;

  /// Ein Abruf oder ein Schreiben läuft.
  final bool laedt;

  /// Im Klartext, was schiefging — null, solange nichts schiefging.
  final String? fehler;

  /// Ob schon einmal geladen wurde. Trennt „noch keine Vorlage angelegt" von
  /// „noch nicht nachgesehen"; ohne diese Angabe zeigte die Verwaltung beim
  /// Aufgehen kurz „keine Vorlagen vorhanden".
  final bool geladen;

  const MailVorlagenState({
    this.vorlagen = const [],
    this.laedt = false,
    this.fehler,
    this.geladen = false,
  });

  MailVorlagenState kopie({
    List<MailVorlage>? vorlagen,
    bool? laedt,
    String? fehler,
    bool? geladen,
  }) => MailVorlagenState(
    vorlagen: vorlagen ?? this.vorlagen,
    laedt: laedt ?? this.laedt,
    // Bewusst nicht `fehler ?? this.fehler`: Ein neuer Versuch soll die alte
    // Meldung loswerden können, und das ginge mit dem Rückfall nie.
    fehler: fehler,
    geladen: geladen ?? this.geladen,
  );

  @override
  List<Object?> get props => [vorlagen, laedt, fehler, geladen];
}
