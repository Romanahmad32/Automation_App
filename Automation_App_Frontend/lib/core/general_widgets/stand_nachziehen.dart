import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Wie [BlocConsumer], aber mit einem Rückruf, der den Zustand **auch dann**
/// bekommt, wenn er beim Aufgehen schon dasteht.
///
/// Der Unterschied ist der ganze Zweck: `BlocListener` hört **Übergänge**. Den
/// Zustand, auf dem der Bloc beim Mounten bereits steht, sieht er nie — es gab
/// dazu keinen Übergang, den er hätte mithören können. Für ein Widget, das
/// beim Aufgehen Felder füllen soll, ist das die falsche Voreinstellung, und
/// zwar auf eine Art, die nichts sagt: Das Formular steht dann auf seinen
/// Vorgabewerten und sieht aus wie ein geladener Stand.
///
/// In dieser App ist das dreimal aufgetreten und zweimal teuer geworden — die
/// E-Mail-Signatur war beim zweiten Öffnen des Reiters leer, der Postfach-Zugang
/// beim ersten Antippen seines Reiters. In beiden Fällen schrieb ein Klick auf
/// „Speichern" die leere Maske über die gepflegten Daten. Die Fälle sind in
/// `mail_signatur_anzeige_test.dart` und `mailbox_zugang_anzeige_test.dart`
/// festgehalten; wer ein weiteres Formular so aufbaut, nimmt diesen Baustein
/// und schreibt den Test nach demselben Muster („war der Bloc schon geladen").
///
/// Die beiden Rückrufe sind getrennt, weil sie verschiedene Fragen
/// beantworten:
///
/// - [nachziehen] — „was zeigt dieses Widget?". Läuft beim Aufgehen **und** bei
///   jedem weiteren Zustand. Muss deshalb wiederholbar sein und darf **kein**
///   `setState` rufen: beim Aufgehen liefe es mitten im Aufbau des Elternteils.
///   Nötig ist es auch nicht — dieser Baustein baut nach jedem Zustand neu,
///   und der [builder] liest die Felder des Elternteils dabei frisch.
/// - [beiUebergang] — „was passiert einmalig?". Nur bei Übergängen, also für
///   Meldungen, Navigation, Fokuswechsel. Eine Erfolgsmeldung gehört hierher:
///   Sie beim Aufgehen zu wiederholen, wäre falsch.
class StandNachziehen<B extends StateStreamable<S>, S> extends StatefulWidget {
  /// Zieht die Anzeige auf [S] nach. Beim Aufgehen und bei jedem Zustand.
  final BlocWidgetListener<S> nachziehen;

  /// Einmalige Reaktion auf einen Zustandswechsel (Meldung, Navigation).
  final BlocWidgetListener<S>? beiUebergang;

  final BlocWidgetBuilder<S> builder;

  const StandNachziehen({
    required this.nachziehen,
    required this.builder,
    this.beiUebergang,
    super.key,
  });

  @override
  State<StandNachziehen<B, S>> createState() => _StandNachziehenState<B, S>();
}

class _StandNachziehenState<B extends StateStreamable<S>, S>
    extends State<StandNachziehen<B, S>> {
  @override
  void initState() {
    super.initState();
    // Der vorhandene Stand, bevor der erste Aufbau läuft: Was hier gesetzt
    // wird, ist im ersten Bild schon da — kein Nachzucken, kein leeres Feld.
    widget.nachziehen(context, context.read<B>().state);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<B, S>(
      listener: (context, stand) {
        // Kein setState: [BlocConsumer] ruft neben diesem Rückruf ohnehin
        // seinen [BlocBuilder] auf, und der liest die Felder des Elternteils
        // frisch (siehe Klassenkommentar oben). Der Rückruf läuft dabei zuerst
        // — der Aufbau sieht die gesetzten Felder also schon. Ein setState
        // hier markierte zusätzlich diesen State und ergäbe zwei Aufbauten je
        // Zustand statt einem.
        widget.nachziehen(context, stand);
        widget.beiUebergang?.call(context, stand);
      },
      builder: widget.builder,
    );
  }
}
