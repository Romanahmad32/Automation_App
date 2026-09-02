import 'package:automation_app/features/mandanten/domain/entities/anrede.dart';
import 'package:equatable/equatable.dart';

/// Der **Anfang** einer Anrede in seinen drei Beugungsformen (§4.7, §7.1) —
/// einer der Anreden, aus denen der Anwalt beim Verfassen wählt.
///
/// Bewusst nur der Anfang: Anredewort und Nachname hängt [zeileFuer] an. Ein
/// Baustein, der die ganze Zeile trüge, müsste den Nachnamen kennen und stünde
/// damit für genau einen Mandanten.
///
/// Drei Formen, weil das Deutsche hier beugt: „Sehr geehrt**er** Herr" gegen
/// „Sehr geehrt**e** Frau". Eine Form für alle hieße, jede zweite Mail falsch
/// anzureden. Lauten alle drei gleich („Guten Tag"), ist das kein Sonderfall,
/// sondern derselbe Text dreimal.
class Anredebaustein extends Equatable {
  /// 0 für einen noch nicht gespeicherten Anfang; die Nummer vergibt der
  /// Bestand.
  final int id;

  /// Anfang für einen männlichen Mandanten, z. B. „Sehr geehrter".
  final String maennlich;

  /// Anfang für eine weibliche Mandantin, z. B. „Sehr geehrte".
  final String weiblich;

  /// Anfang ohne Geschlechtsbezug — davor steht dann „Damen und Herren" statt
  /// Herr/Frau und Nachname.
  final String neutral;

  /// Reihenfolge in der Auswahl; 0 heißt „ans Ende".
  final int sortierung;

  const Anredebaustein({
    this.id = 0,
    this.maennlich = '',
    this.weiblich = '',
    this.neutral = '',
    this.sortierung = 0,
  });

  bool get istGespeichert => id > 0;

  /// Der Anfang, der gilt, wenn der Bestand **leer** ist — wörtlich der erste
  /// des Ausgangsbestands (`AnredeBausteineVorgabe` im Dienst) und damit die
  /// Anrede, die die App vor dem 02.09.2026 fest erzeugt hat.
  ///
  /// **Warum eine Konstante und nicht ein zweiter Wortlaut** (ergänzt am
  /// 02.09.2026): Der Rückfall lief über `Anrede.briefanrede` — eine eigene
  /// Kopie von „Sehr geehrter"/„Sehr geehrte", die die je Mail **gewählte**
  /// Anredeart nicht kannte, weil sie nur den Registereintrag des Mandanten
  /// las. Wer sie wählte, bekam „unserer Mandantin" im Text und „Sehr geehrte
  /// Damen und Herren" darüber — genau der Auseinanderlauf, den
  /// `EmailEntwurfErzeuger.geschlechtFuer` verhindern soll. Über [zeileFuer]
  /// gilt für den Rückfall dieselbe Rechnung wie für jeden gespeicherten
  /// Anfang.
  ///
  /// `Anrede.briefanrede` bleibt trotzdem: Sie füllt `{{Anrede}}` in den
  /// **Word**-Vorlagen, und dort gibt es keine Wahl je Mail. Dass beide
  /// dasselbe schreiben, hält `anredebaustein_test.dart` fest.
  static const Anredebaustein rueckfall = Anredebaustein(
    maennlich: 'Sehr geehrter',
    weiblich: 'Sehr geehrte',
    neutral: 'Sehr geehrte',
  );

  /// Die fertige Anredezeile — **ohne Komma**: Das setzt die Vorlage hinter
  /// `{{Anrede}}`, damit jede Vorlage selbst bestimmt, wie es weitergeht.
  ///
  /// Drei Lagen, und sie unterscheiden sich darin, **was preisgegeben wird**:
  ///
  /// * [Anrede.keine] — es gibt nichts zu beugen: „Sehr geehrte Damen und
  ///   Herren". Das ist auch der Weg zurück, wenn der Anwalt die neutrale
  ///   Form ausdrücklich will.
  /// * [persoenlich] false **und ein Nachname vorhanden** — dann liest neben
  ///   dem Mandanten jemand mit, und die Zeile bleibt neutral: Sie soll den
  ///   Namen nicht vor der Gegenseite nennen.
  /// * sonst folgt die Zeile der Anredeart. **Ohne Nachnamen steht sie allein
  ///   da** („Sehr geehrter Herr") — geändert am 03.09.2026: Vorher fiel jede
  ///   Wahl ohne Nachnamen auf „Damen und Herren" zurück, und bei einem
  ///   Vorgang ohne Registermandanten sahen alle Chips gleich aus. Wer „Herr"
  ///   wählt, soll „Herr" lesen; zu verschweigen ist hier auch nichts, denn
  ///   ohne Namen verrät die Zeile niemanden.
  String zeileFuer({
    required Anrede anrede,
    required String nachname,
    required bool persoenlich,
  }) {
    final name = nachname.trim();
    if (anrede == Anrede.keine) return _zusammen(neutral, 'Damen und Herren');
    if (!persoenlich && name.isNotEmpty) {
      return _zusammen(neutral, 'Damen und Herren');
    }
    return switch (anrede) {
      Anrede.herr => _zusammen(maennlich, _mitNamen('Herr', name)),
      Anrede.frau => _zusammen(weiblich, _mitNamen('Frau', name)),
      Anrede.keine => _zusammen(neutral, 'Damen und Herren'),
    };
  }

  /// Anredewort und Nachname — oder das Anredewort allein, wenn keiner
  /// bekannt ist.
  static String _mitNamen(String wort, String name) =>
      name.isEmpty ? wort : '$wort $name';

  /// Anfang und Rest mit genau einem Leerzeichen. Ein leerer Anfang darf keine
  /// Zeile erzeugen, die mit einem Leerzeichen beginnt.
  static String _zusammen(String anfang, String rest) =>
      [anfang.trim(), rest].where((teil) => teil.isNotEmpty).join(' ');

  /// Wie der Baustein in der Verwaltung heißt — die männliche Form, weil sie
  /// die gebeugte ist und den Baustein damit erkennbar macht.
  String get bezeichnung =>
      maennlich.trim().isEmpty ? neutral.trim() : maennlich.trim();

  factory Anredebaustein.fromJson(Map<String, dynamic> json) => Anredebaustein(
    id: json['id'] as int? ?? 0,
    maennlich: json['maennlich'] as String? ?? '',
    weiblich: json['weiblich'] as String? ?? '',
    neutral: json['neutral'] as String? ?? '',
    sortierung: json['sortierung'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'maennlich': maennlich,
    'weiblich': weiblich,
    'neutral': neutral,
    'sortierung': sortierung,
  };

  Anredebaustein copyWith({
    String? maennlich,
    String? weiblich,
    String? neutral,
    int? sortierung,
  }) => Anredebaustein(
    id: id,
    maennlich: maennlich ?? this.maennlich,
    weiblich: weiblich ?? this.weiblich,
    neutral: neutral ?? this.neutral,
    sortierung: sortierung ?? this.sortierung,
  );

  @override
  List<Object?> get props => [id, maennlich, weiblich, neutral, sortierung];
}
