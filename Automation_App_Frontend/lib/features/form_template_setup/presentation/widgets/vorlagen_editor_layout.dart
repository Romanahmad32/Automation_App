import 'package:flutter/material.dart';

/// Baut die Feldertabelle des Vorlageneditors.
///
/// [eigenerScrollbereich] sagt, in welcher der beiden Anordnungen sie gerade
/// steht: zweispaltig scrollt die Tabelle **für sich** (Kartenkopf und
/// Tabellenkopf bleiben stehen, die Liste ist echt virtualisiert), gestapelt
/// scrollt sie mit der Seite und darf deshalb keinen zweiten Scrollbereich
/// aufmachen. Die Entscheidung trifft [VorlagenEditorLayout] — es ist die
/// einzige Stelle, die die Breite kennt.
typedef FelderBauer =
    Widget Function(BuildContext context, bool eigenerScrollbereich);

/// Die Anordnung der Seite „Vorlage bearbeiten" (#104 Stufe 3a) — und sonst
/// nichts.
///
/// Das Widget nimmt die fertigen Bausteine als Slots entgegen und entscheidet
/// allein, wo sie stehen und wer scrollt. Nur so bleibt
/// `form_template_details_page.dart` reine Verdrahtung (Zeilenbudget, siehe
/// `FALLSTRICKE.md` → „VorlagenBearbeitung"), und nur so ist die Anordnung
/// ohne Blocs und ohne Formular prüfbar: Der Test steckt `SizedBox`en mit
/// Schlüsseln hinein und misst.
///
/// **Ab [zweiSpaltenAb] zwei Spalten**, darunter ein Stapel:
///
/// - Über beiden: die Kopfzeile aus Überschrift und Aktionsknöpfen. Die Knöpfe
///   stehen **oben**, nicht mehr unter der Feldertabelle — bei einer Vorlage
///   mit achtzehn Feldern lagen sie sonst hinter einem Bildschirmlauf, und in
///   der zweispaltigen Fassung gäbe es unter zwei getrennt scrollenden Spalten
///   überhaupt keinen gemeinsamen Fuß mehr.
/// - Links [linkeSpalteBreite] fest: die Dateien und alles, was zu ihnen
///   gehört. Fest statt anteilig, weil ihr Inhalt nicht von Breite lebt — eine
///   Dateikarte wird durch 600 px nicht besser, die Feldertabelle daneben
///   schon.
/// - Rechts füllend die Feldertabelle, mit eigenem Scrollbereich.
///
/// **Zweispaltig braucht eine begrenzte Höhe** (wie `EmailVersandInhalt`):
/// Zwei Spalten, die für sich scrollen, haben sonst nichts, worin sie sich
/// ausdehnen könnten. Unter einem `Scaffold`-Rumpf ist das gegeben; wer das
/// Layout in einen Scrollbereich hängt, bekommt zu Recht einen Fehler.
class VorlagenEditorLayout extends StatelessWidget {
  /// Ab dieser **Inhaltsbreite** (Fensterbreite abzüglich [seitenrand]) stehen
  /// zwei Spalten nebeneinander.
  ///
  /// Die Zahl ist keine Geschmacksfrage, sie folgt aus der rechten Spalte: Die
  /// Felderkarte ist bei `Schriftstufe.amGroessten` bis 700 px hinunter
  /// überlauffrei — das hält `felder_karte_schmal_test.dart` fest, und tiefer
  /// ist es nicht geprüft. 1180 − 400 (links) − 16 (Spalt) lässt ihr 764 px,
  /// also noch Luft über dem geprüften Rand. Der Wert deckt sich mit
  /// `EmailVersandInhalt.zweiSpaltenAb`; das ist ein Zufall aus derselben
  /// Rechnung und kein gemeinsamer Beschluss — deshalb steht er hier und nicht
  /// als geteilte Konstante in `core/general_widgets/layout/`. Eine Schwelle,
  /// die drei Layouts teilen (`KartenSpalten` rechnet mit 1080), wäre eine
  /// Zahl, um die sich drei Seiten streiten.
  static const double zweiSpaltenAb = 1180;

  /// Die feste Breite der linken Spalte.
  static const double linkeSpalteBreite = 400;

  /// Abstand zwischen den Karten und zwischen den Spalten.
  static const double abstand = 16;

  /// Der Rand um die ganze Seite — derselbe wie vor Stufe 3a.
  static const EdgeInsets seitenrand = EdgeInsets.symmetric(
    horizontal: 15,
    vertical: 10,
  );

  /// Schlüssel der linken Spalte, damit ein Test ihre Breite messen kann —
  /// und ihr Fehlen als „gestapelt" lesen.
  static const Key linkeSpalteSchluessel = ValueKey(
    'vorlagen_editor_linke_spalte',
  );

  /// Schlüssel der Kopfzeile: Sie trägt in **beiden** Anordnungen Überschrift
  /// und Knöpfe.
  static const Key kopfzeileSchluessel = ValueKey('vorlagen_editor_kopfzeile');

  /// Die Überschrift der Seite.
  final Widget kopf;

  /// Abbrechen und Speichern — oben rechts neben [kopf].
  final Widget knopfzeile;

  /// Der Vorlagenname, über volle Breite unter der Kopfzeile.
  final Widget namensKarte;

  /// Was in die linke Spalte gehört, von oben nach unten. Gestapelt läuft es
  /// in derselben Reihenfolge weiter — deshalb steht hier vorn, was zuerst
  /// gelesen werden soll.
  final List<Widget> linkeSpalte;

  /// Die Feldertabelle. Kein fertiges Widget, sondern ein Bauer: Sie muss
  /// wissen, ob sie ihren eigenen Scrollbereich bekommt, und das weiß erst
  /// dieses Layout.
  final FelderBauer felder;

  /// Die eine Frage am Anfang einer neuen Vorlage („Womit fängt diese Vorlage
  /// an?", `VorlagenLeerzustand`) — null im Regelfall.
  ///
  /// Ist er gesetzt, zeigt das Layout **nur** Kopfzeile und ihn:
  /// [namensKarte], [linkeSpalte] und [felder] bleiben ungebaut. Die
  /// Entscheidung steht hier und nicht in der Seite, weil die Anordnung der
  /// Seite ganz diesem Widget gehört — die Seite sagt nur, *ob* der
  /// Leerzustand gilt (`VorlagenBearbeitung.zeigtLeerzustand`).
  final Widget? leerzustand;

  const VorlagenEditorLayout({
    super.key,
    required this.kopf,
    required this.knopfzeile,
    required this.namensKarte,
    required this.linkeSpalte,
    required this.felder,
    this.leerzustand,
  });

  /// Ob [inhaltsbreite] für zwei Spalten reicht.
  static bool zweispaltig(double inhaltsbreite) =>
      inhaltsbreite >= zweiSpaltenAb;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: seitenrand,
      // Der `LayoutBuilder` sitzt **innerhalb** des Randes: Gemessen wird der
      // Platz, den die Spalten wirklich bekommen, nicht die Fensterbreite.
      // Sonst hinge die Schwelle daran, wie breit der Rand gerade ist.
      child: leerzustand != null
          ? _leer()
          : LayoutBuilder(
              builder: (context, constraints) =>
                  zweispaltig(constraints.maxWidth)
                  ? _nebeneinander(context)
                  : _gestapelt(context),
            ),
    );
  }

  /// Kopfzeile und die eine Frage darunter — keine Spalten, keine Breiten-
  /// schwelle: Es steht nur ein Baustein da, und der bringt seine eigene
  /// Umbruchregel mit (`VorlagenLeerzustand.zweispaltigAb`).
  ///
  /// Der `SingleChildScrollView` ist kein Zierrat: Bei der größten
  /// Schriftstufe (#57) und niedrigem Fenster ist auch diese eine Karte höher
  /// als der Rumpf.
  Widget _leer() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: abstand,
      children: [_kopfzeile(), leerzustand!],
    ),
  );

  /// Überschrift links, Knöpfe rechts.
  ///
  /// `Wrap` statt `Row` aus demselben Grund wie in `FelderKarteKopf`: Bei
  /// angehobener Schrift (Issue #57) und schmalem Fenster reicht die Breite
  /// nicht für beides nebeneinander, und ein `Spacer` kann nicht auf negative
  /// Breite schrumpfen. Die Knöpfe rutschen dann unter die Überschrift.
  ///
  /// Das [IntrinsicWidth] ist kein Beiwerk: `Wrap` gibt seinen Kindern lose
  /// Randbedingungen, und eine `Row` mit `MainAxisSize.max` — genau das ist
  /// die Knopfzeile — nähme darin die volle Breite ein. `spaceBetween` hätte
  /// dann nichts mehr zu verteilen und die Knöpfe stünden immer auf einer
  /// eigenen Zeile. Hier statt in der Knopfzeile, weil ein Layout mit jedem
  /// Slot zurechtkommen muss, den man ihm gibt.
  Widget _kopfzeile() => Wrap(
    key: kopfzeileSchluessel,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      kopf,
      IntrinsicWidth(child: knopfzeile),
    ],
  );

  Widget _nebeneinander(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _kopfzeile(),
        const SizedBox(height: abstand),
        namensKarte,
        const SizedBox(height: abstand),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: linkeSpalteSchluessel,
                width: linkeSpalteBreite,
                // Eigener Scrollbereich: Die Dateikarten samt Platzhaltern
                // sind länger als die Feldertabelle daneben kurz ist. Eine
                // gemeinsame Scrollspalte zöge die Tabelle mit nach oben aus
                // dem Bild.
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: abstand,
                    children: linkeSpalte,
                  ),
                ),
              ),
              const SizedBox(width: abstand),
              Expanded(child: felder(context, true)),
            ],
          ),
        ),
      ],
    );
  }

  /// Alles untereinander in **einer** Scrollspalte.
  ///
  /// Die Feldertabelle bekommt hier ausdrücklich **keinen** eigenen
  /// Scrollbereich: Ein Scrollbereich in einem Scrollbereich hat keine eigene
  /// Höhe, und der Anwalt müsste raten, welches Rad gerade welche Liste
  /// bewegt.
  Widget _gestapelt(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: abstand,
        children: [
          _kopfzeile(),
          namensKarte,
          ...linkeSpalte,
          felder(context, false),
        ],
      ),
    );
  }
}
