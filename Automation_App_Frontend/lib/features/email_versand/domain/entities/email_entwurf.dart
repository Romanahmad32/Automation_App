import 'package:equatable/equatable.dart';

/// Die Mail, wie der Anwalt sie gerade verfasst (§4.7). Reiner Zustand ohne
/// Versandlogik — dieselbe Form geht am Ende an das Backend.
class EmailEntwurf extends Equatable {
  final List<String> an;
  final List<String> kopie;
  final String betreff;
  final String text;

  /// Vollständige Pfade der Anhänge. Dienst und Oberfläche laufen auf einem
  /// Rechner; der Weg über Pfade erspart es, jede Datei durch die
  /// HTTP-Schnittstelle zu schieben (wie bei der Ablage in der Akte).
  final List<String> anhangPfade;

  /// Abweichender Dateiname je Anhangpfad, wenn der Anwalt umbenannt hat.
  /// Die Datei in der Akte behält ihren Namen — geändert wird nur, was beim
  /// Empfänger ankommt: „Dokument1.pdf" sagt dort niemandem etwas.
  final Map<String, String> anhangNamen;

  /// Dateinamen der Signaturbilder, die bei **dieser** Mail wegbleiben. Leer
  /// heißt: alle gehen mit. Die Signatur in den Einstellungen bleibt davon
  /// unberührt — entschieden wird je Nachricht, weil das schwere Werbebild
  /// nicht unter jede gehört (§4.7).
  final List<String> ohneSignaturBilder;

  /// Der Vorgang, zu dem die Mail gehört. Er wandert mit ans Backend, das den
  /// Versand darunter protokolliert (§4.7). Leer bei einem Anschreiben ohne
  /// Vorgang — dann entsteht kein Eintrag, weil es keine Akte gibt, an der er
  /// hinge.
  final String vorgangReferenz;

  const EmailEntwurf({
    this.an = const [],
    this.kopie = const [],
    this.betreff = '',
    this.text = '',
    this.anhangPfade = const [],
    this.anhangNamen = const {},
    this.ohneSignaturBilder = const [],
    this.vorgangReferenz = '',
  });

  /// Alle angeschriebenen Adressen, für Rückfrage und Zusammenfassung.
  List<String> get alleEmpfaenger => [...an, ...kopie];

  EmailEntwurf copyWith({
    List<String>? an,
    List<String>? kopie,
    String? betreff,
    String? text,
    List<String>? anhangPfade,
    Map<String, String>? anhangNamen,
    List<String>? ohneSignaturBilder,
    String? vorgangReferenz,
  }) {
    return EmailEntwurf(
      an: an ?? this.an,
      kopie: kopie ?? this.kopie,
      betreff: betreff ?? this.betreff,
      text: text ?? this.text,
      anhangPfade: anhangPfade ?? this.anhangPfade,
      anhangNamen: anhangNamen ?? this.anhangNamen,
      ohneSignaturBilder: ohneSignaturBilder ?? this.ohneSignaturBilder,
      vorgangReferenz: vorgangReferenz ?? this.vorgangReferenz,
    );
  }

  Map<String, dynamic> toJson(String absenderName) => {
    'an': an,
    'kopie': kopie,
    'betreff': betreff,
    'text': text,
    'anhangPfade': anhangPfade,
    'anhangNamen': anhangNamen,
    'ohneSignaturBilder': ohneSignaturBilder,
    'vorgangReferenz': vorgangReferenz,
    'absenderName': absenderName,
  };

  /// Nimmt ein Signaturbild für diese Mail heraus oder wieder hinein.
  EmailEntwurf mitUmgeschaltetemSignaturBild(String dateiname) =>
      ohneSignaturBilder.contains(dateiname)
      ? copyWith(
          ohneSignaturBilder: ohneSignaturBilder
              .where((weg) => weg != dateiname)
              .toList(),
        )
      : copyWith(ohneSignaturBilder: [...ohneSignaturBilder, dateiname]);

  bool signaturBildGehtMit(String dateiname) =>
      !ohneSignaturBilder.contains(dateiname);

  /// Nimmt die Adresse in „An" auf — es sei denn, sie steht schon irgendwo.
  /// Wer zweimal angeschrieben wird, merkt das; die App soll es verhindern.
  EmailEntwurf mitEmpfaenger(String adresse) =>
      enthaelt(adresse) ? this : copyWith(an: [...an, adresse.trim()]);

  EmailEntwurf mitKopie(String adresse) =>
      enthaelt(adresse) ? this : copyWith(kopie: [...kopie, adresse.trim()]);

  EmailEntwurf ohneEmpfaenger(String adresse) => copyWith(
    an: an.where((vorhanden) => vorhanden != adresse).toList(),
    kopie: kopie.where((vorhanden) => vorhanden != adresse).toList(),
  );

  /// Gross- und Kleinschreibung zaehlen bei Adressen nicht.
  bool enthaelt(String adresse) {
    final gesucht = adresse.trim().toLowerCase();
    return gesucht.isEmpty ||
        alleEmpfaenger.any((vorhanden) => vorhanden.toLowerCase() == gesucht);
  }

  EmailEntwurf mitAnhang(String pfad) => anhangPfade.contains(pfad)
      ? this
      : copyWith(anhangPfade: [...anhangPfade, pfad]);

  EmailEntwurf ohneAnhang(String pfad) => copyWith(
    anhangPfade: anhangPfade.where((vorhanden) => vorhanden != pfad).toList(),
    anhangNamen: {...anhangNamen}..remove(pfad),
  );

  /// Ein leerer Name stellt den Dateinamen auf Platte wieder her.
  EmailEntwurf mitAnhangName(String pfad, String name) {
    final namen = {...anhangNamen};
    final sauber = name.trim();
    if (sauber.isEmpty) {
      namen.remove(pfad);
    } else {
      namen[pfad] = sauber;
    }
    return copyWith(anhangNamen: namen);
  }

  /// Der Name, unter dem ein Anhang hinausgeht: der umbenannte, sonst der
  /// Dateiname auf Platte.
  String nameVon(String pfad) =>
      anhangNamen[pfad] ?? pfad.split(RegExp('[\\\\/]')).last;

  @override
  List<Object?> get props => [
    an,
    kopie,
    betreff,
    text,
    anhangPfade,
    anhangNamen,
    ohneSignaturBilder,
    vorgangReferenz,
  ];
}
