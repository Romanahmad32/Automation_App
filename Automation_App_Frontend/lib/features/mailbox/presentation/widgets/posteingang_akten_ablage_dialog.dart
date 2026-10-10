import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/general_widgets/rueckmeldung/rueckmeldung.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_akten_ablage_felder.dart';
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart';
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/word_automation/presentation/utils/ablage_durchfuehrung.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Legt einen Anhang oder eine ganze Nachricht (`.eml`) aus dem Posteingang in
/// der Akte ab (§4.3) — über den vorhandenen [AblageCubit] samt Konfliktfrage
/// (`klaereAblageKonflikt`, unverändert übernommen aus
/// `word_automation/presentation/utils/ablage_durchfuehrung.dart`).
///
/// Ist der Vorgang erkannt, sind Mandant, Akte und Fall-Ordner vorbelegt: der
/// Mandant aus `vorgang.mandantId`, die Akte aus `vorgang.aktenOrdner`, der
/// Fall-Ordner aus dem Elternordner von `vorgang.dokumentPfad`. Fehlt eines
/// davon — kein Vorgang erkannt, oder das Schreiben liegt noch nicht in der
/// Akte —, wählt der Anwalt es aus dem Bestand aus (siehe
/// [PosteingangAktenAblageFelder]); getippt wird nur, wo es nichts
/// auszuwählen gibt.
///
/// Anders als der Speicherschritt des Wizards (§6.1, `AktenAblageSection`)
/// kennt dieser Dialog keine Formatwahl und keinen „neu anlegen"-Zweig: Es
/// gibt nur die eine mitgegebene Datei-Gruppe, und eine Mail wird in einen
/// **bestehenden** Fall gelegt — entsteht der Fall erst, ist der Wizard die
/// Stelle dafür.
class PosteingangAktenAblageDialog extends StatefulWidget {
  const PosteingangAktenAblageDialog({
    super.key,
    required this.pfade,
    this.vorgang,
  });

  final List<String> pfade;
  final Vorgang? vorgang;

  /// Zeigt den Dialog; liefert true, sobald abgelegt wurde.
  static Future<bool> zeigen(
    BuildContext context, {
    required List<String> pfade,
    Vorgang? vorgang,
  }) async {
    final ergebnis = await showDialog<bool>(
      context: context,
      builder: (_) => BlocProvider(
        create: (_) => getIt<AblageCubit>()..laden(),
        child: PosteingangAktenAblageDialog(pfade: pfade, vorgang: vorgang),
      ),
    );
    return ergebnis ?? false;
  }

  @override
  State<PosteingangAktenAblageDialog> createState() =>
      _PosteingangAktenAblageDialogState();
}

class _PosteingangAktenAblageDialogState
    extends State<PosteingangAktenAblageDialog> {
  Mandant? _mandant;
  final _aktenController = TextEditingController();
  final _unterordnerController = TextEditingController();

  /// Nur einmal vorbelegen, sobald die Mandanten geladen sind — ein bewusst
  /// geänderter Wert des Anwalts bleibt danach stehen.
  bool _vorbelegt = false;

  @override
  void dispose() {
    _aktenController.dispose();
    _unterordnerController.dispose();
    super.dispose();
  }

  void _vorbelegen(List<Mandant> mandanten) {
    _vorbelegt = true;
    final vorgang = widget.vorgang;
    if (vorgang == null) return;
    setState(() {
      _mandant = mandanten.where((m) => m.id == vorgang.mandantId).firstOrNull;
      _aktenController.text = vorgang.aktenOrdner ?? '';
      _unterordnerController.text = _fallOrdnerName(vorgang.dokumentPfad);
    });
    _faelleLaden(_aktenController.text);
  }

  /// Der Ordnername des Falls — der Elternordner der abgelegten Datei, ohne
  /// den vollen Pfad: `ablegenFuerMandant` erwartet nur den Namen.
  String _fallOrdnerName(String? dokumentPfad) {
    if (dokumentPfad == null || dokumentPfad.trim().isEmpty) return '';
    final teile = dokumentPfad.split(RegExp(r'[\\/]+'))
      ..removeWhere((teil) => teil.isEmpty);
    return teile.length < 2 ? '' : teile[teile.length - 2];
  }

  /// Die Fälle einer Akte liest der Cubit erst auf Nachfrage (ein Scan je
  /// Akte statt eines Baumdurchlaufs über alle).
  void _faelleLaden(String akte) {
    if (akte.trim().isEmpty) return;
    context.read<AblageCubit>().faelleLaden(akte.trim());
  }

  /// Zur Auswahl stehen die Akten des Mandanten; ist keine hinterlegt, alle
  /// gescannten. Der vorbelegte Wert kommt immer dazu — sonst stünde im Feld
  /// ein Name, den die Liste darunter nicht kennt.
  List<String> _aktenVorschlaege(AblageState state) {
    final namen = <String>{
      ...?_mandant?.aktenOrdnernamen,
      if (_aktenController.text.trim().isNotEmpty) _aktenController.text.trim(),
    };
    if (namen.isEmpty) {
      namen.addAll(state.akten.map((akte) => akte.ordnername));
    }
    return namen.toList();
  }

  List<String> _fallVorschlaege(AblageState state) {
    final akte = _aktenController.text.trim();
    final treffer = state.akten
        .where((eintrag) => eintrag.ordnername == akte)
        .firstOrNull;
    return <String>{
      ...?treffer?.faelle.map((fall) => fall.name),
      if (_unterordnerController.text.trim().isNotEmpty)
        _unterordnerController.text.trim(),
    }.toList();
  }

  void _setzeAkte(String wert) {
    setState(() {
      _aktenController.text = wert;
      // Ein Fall gehört zu genau einer Akte — nach dem Wechsel ist der alte
      // Name keine Auskunft mehr, sondern eine falsche.
      _unterordnerController.clear();
    });
    _faelleLaden(wert);
  }

  Future<void> _ablegen(BuildContext context) async {
    final mandant = _mandant;
    final akte = _aktenController.text.trim();
    final unterordner = _unterordnerController.text.trim();
    if (mandant == null || akte.isEmpty || unterordner.isEmpty) {
      Rueckmeldung.zeigeHinweis(
        context,
        'Bitte Mandant, Akte und Fall-Ordner angeben.',
      );
      return;
    }
    await context.read<AblageCubit>().ablegenFuerMandant(
      mandantId: mandant.id,
      aktenOrdnername: akte,
      unterordnerName: unterordner,
      quelldateiPfade: widget.pfade,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AblageCubit, AblageState>(
      listener: (context, state) {
        if (state.status == AblageStatus.konflikt) {
          klaereAblageKonflikt(context, state.konfliktPfade);
        } else if (state.status == AblageStatus.erfolg) {
          Rueckmeldung.zeigeErfolg(context, 'In der Akte abgelegt.');
          Navigator.pop(context, true);
        } else if (state.status == AblageStatus.fehler &&
            state.message != null) {
          Rueckmeldung.zeigeFehler(context, state.message!);
        } else if (state.status == AblageStatus.ready && !_vorbelegt) {
          _vorbelegen(state.mandanten);
        }
      },
      builder: (context, state) {
        final laedt =
            state.status == AblageStatus.loading ||
            state.status == AblageStatus.initial;
        final legtAb = state.status == AblageStatus.filing;

        return AlertDialog(
          title: const Text('In die Akte legen'),
          content: SizedBox(
            width: 460,
            child: laedt
                ? const SizedBox(
                    height: 96,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SingleChildScrollView(
                    child: PosteingangAktenAblageFelder(
                      mandant: _mandant,
                      mandanten: state.mandanten,
                      onMandant: (wert) => setState(() => _mandant = wert),
                      akteController: _aktenController,
                      aktenVorschlaege: _aktenVorschlaege(state),
                      onAkte: _setzeAkte,
                      fallController: _unterordnerController,
                      fallVorschlaege: _fallVorschlaege(state),
                      onFall: (wert) =>
                          setState(() => _unterordnerController.text = wert),
                      legtAb: legtAb,
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: legtAb ? null : () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: (legtAb || laedt) ? null : () => _ablegen(context),
              child: legtAb
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ablegen'),
            ),
          ],
        );
      },
    );
  }
}
