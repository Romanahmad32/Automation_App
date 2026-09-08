import 'package:automation_app/core/general_classes/failures/failure.dart';
import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_bericht.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_datei.dart';
import 'package:automation_app/features/register_import/domain/entities/register_import_zeile.dart';
import 'package:automation_app/features/register_import/domain/entities/register_zeilen_befund.dart';
import 'package:automation_app/features/register_import/domain/usecases/importiere_register.dart';
import 'package:automation_app/features/register_import/domain/usecases/lies_register_import_datei.dart';
import 'package:automation_app/features/register_import/presentation/blocs/register_import_cubit/register_import_cubit.dart';
import 'package:automation_app/features/register_import/presentation/views/register_import_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Attrappen und Bausteine für die Tests rund um den [RegisterImportCubit].
///
/// Kein Mocking-Paket und kein GetIt: Die beiden UseCases sind Schnittstellen
/// mit je einer Methode, und eine handgeschriebene Attrappe sagt in derselben
/// Zeilenzahl mehr — sie hält fest, **was** geschickt wurde.

/// Die Importansicht unter ihrem Cubit — so, wie die Seite sie aufhängt.
Widget registerImportSeite(RegisterImportCubit cubit) => MaterialApp(
  home: Scaffold(
    body: BlocProvider.value(
      value: cubit,
      child: BlocBuilder<RegisterImportCubit, RegisterImportState>(
        builder: (context, state) => RegisterImportView(state: state),
      ),
    ),
  ),
);

RegisterImportZeile zeile(
  int nummer, {
  String mandant = 'Max Mustermann',
  String gegner = 'HUK',
  String sachart = '',
  String abteilung = 'C03',
  String rechtsgebiet = 'Verkehrsrecht',
  String sicherheit = 'hoch',
  String spalte1 = '',
  int jahrgang = 2022,
  List<String> hinweise = const [],
}) => RegisterImportZeile(
  laufendeNummer: nummer,
  spalte1: spalte1.isEmpty ? '$nummer' : spalte1,
  aktenzeichen: '$nummer/${jahrgang % 100}',
  abteilung: abteilung,
  abteilungRoh: abteilung,
  sachart: sachart,
  mandant: mandant,
  gegner: gegner,
  rechtsgebiet: rechtsgebiet,
  freitext: '$nummer/${jahrgang % 100} $abteilung $mandant ./. $gegner',
  sicherheit: sicherheit,
  hinweise: hinweise,
);

RegisterImportDatei registerDatei({
  int jahrgang = 2022,
  List<RegisterImportZeile>? zeilen,
}) => RegisterImportDatei(
  jahrgaenge: [
    RegisterImportJahrgang(
      jahrgang: jahrgang,
      zeilen: zeilen ?? [zeile(1), zeile(2, sicherheit: 'niedrig')],
    ),
  ],
);

RegisterImportDatei registerDateiMitJahrgaengen(
  Map<int, List<RegisterImportZeile>> jahrgaenge,
) => RegisterImportDatei(
  jahrgaenge: [
    for (final eintrag in jahrgaenge.entries)
      RegisterImportJahrgang(jahrgang: eintrag.key, zeilen: eintrag.value),
  ],
);

/// Der Bericht, den ein Dienst zu dieser Datei liefern würde — nachgebaut, weil
/// die Vorschau je Jahrgang genau das ist, was hier geprüft wird: Lücken,
/// „zu prüfen", und die 1-basierte Zeilennummer innerhalb ihres Jahrgangs.
RegisterImportBericht berichtAus(RegisterImportDatei datei) =>
    RegisterImportBericht(
      jahrgaenge: [for (final jahr in datei.jahrgaenge) befundAus(jahr)],
    );

JahrgangBefund befundAus(RegisterImportJahrgang jahr) {
  final nummern = {for (final z in jahr.zeilen) z.laufendeNummer};
  var hoechste = 0;
  for (final nummer in nummern) {
    if (nummer > hoechste) hoechste = nummer;
  }

  final eintraege = <RegisterZeilenBefund>[];
  for (var i = 0; i < jahr.zeilen.length; i++) {
    final z = jahr.zeilen[i];
    final stufe = ImportSicherheit.ausWert(z.sicherheit);
    final befunde = <String>[
      if (z.spalte1.isNotEmpty && z.spalte1 != '${z.laufendeNummer}')
        'Spalte 1 „${z.spalte1}" widerspricht der Nummer ${z.laufendeNummer}.',
    ];
    eintraege.add(
      RegisterZeilenBefund(
        zeile: i + 1,
        jahrgang: jahr.jahrgang,
        laufendeNummer: z.laufendeNummer,
        aktenzeichen: z.aktenzeichen,
        anzeigetext: z.gegner.isEmpty
            ? '${z.sachart} ${z.mandant}'.trim()
            : '${z.mandant} ./. ${z.gegner}',
        rechtsgebiet: z.rechtsgebiet,
        sicherheit: stufe,
        art: ImportArt.neu,
        befunde: befunde,
        hinweise: z.hinweise,
        zuPruefen: stufe != ImportSicherheit.hoch || befunde.isNotEmpty,
      ),
    );
  }

  return JahrgangBefund(
    jahrgang: jahr.jahrgang,
    zeilen: jahr.zeilen.length,
    luecken: [
      for (var n = 1; n <= hoechste; n++)
        if (!nummern.contains(n)) n,
    ],
    neu: jahr.zeilen.length,
    zuPruefen: eintraege.where((e) => e.zuPruefen).length,
    eintraege: eintraege,
  );
}

/// Liefert eine Datei — oder scheitert, wenn [fehler] gesetzt ist.
class FesteRegisterDatei
    implements UseCase<RegisterImportDatei, LiesRegisterImportDateiParams> {
  final RegisterImportDatei inhalt;
  String? fehler;
  int aufrufe = 0;

  FesteRegisterDatei(this.inhalt, {this.fehler});

  @override
  Future<Either<Failure, RegisterImportDatei>> call(
    LiesRegisterImportDateiParams params,
  ) async {
    aufrufe++;
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));
    return Right(inhalt);
  }
}

/// Merkt sich, ob geprüft oder geschrieben wurde — und **was** dabei über die
/// Leitung ging. Das ist der Kern: Vor der ersten Vorschau darf nichts
/// geschrieben werden, und „Jahrgang übernehmen" darf nur diesen einen
/// schicken.
class AufzeichnenderRegisterImport
    implements UseCase<RegisterImportBericht, ImportiereRegisterParams> {
  /// Ob der jeweilige Aufruf schreiben sollte — in der Reihenfolge.
  final List<bool> aufrufe = [];

  /// Die Datei, wie sie beim jeweiligen Aufruf über die Leitung ging.
  final List<RegisterImportDatei> gesendet = [];

  /// Antwortet abhängig von der geschickten Datei. Ohne eigene Vorgabe baut
  /// [berichtAus] den Bericht nach.
  final RegisterImportBericht Function(RegisterImportDatei datei)? berichtVon;

  String? fehler;

  AufzeichnenderRegisterImport({this.berichtVon, this.fehler});

  int get schreibendeAufrufe => aufrufe.where((u) => u).length;

  @override
  Future<Either<Failure, RegisterImportBericht>> call(
    ImportiereRegisterParams params,
  ) async {
    aufrufe.add(params.uebernehmen);
    gesendet.add(params.datei);
    final grund = fehler;
    if (grund != null) return Left(LocalFailure(message: grund));

    final basis = (berichtVon ?? berichtAus)(params.datei);
    return Right(
      RegisterImportBericht(
        jahrgaenge: basis.jahrgaenge,
        angewendet: params.uebernehmen,
      ),
    );
  }
}

/// Cubit samt seinen Attrappen.
class RegisterImportTestaufbau {
  final FesteRegisterDatei lesen;
  final AufzeichnenderRegisterImport importieren;
  final RegisterImportCubit cubit;

  RegisterImportTestaufbau._(this.lesen, this.importieren, this.cubit);

  factory RegisterImportTestaufbau({
    RegisterImportDatei? inhalt,
    RegisterImportBericht Function(RegisterImportDatei datei)? berichtVon,
  }) {
    final lesen = FesteRegisterDatei(inhalt ?? registerDatei());
    final importieren = AufzeichnenderRegisterImport(berichtVon: berichtVon);
    return RegisterImportTestaufbau._(
      lesen,
      importieren,
      RegisterImportCubit(lesen, importieren),
    );
  }

  /// Der übliche Einstieg: Datei wählen, Vorschau steht.
  Future<void> geoeffnet([String pfad = 'C:/tmp/register-2022.json']) =>
      cubit.dateiWaehlen(pfad);

  Future<void> close() => cubit.close();
}
