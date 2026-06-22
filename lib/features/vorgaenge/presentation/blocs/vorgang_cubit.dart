import 'package:automation_app/features/vorgaenge/domain/entities/rechtsgebiet.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/zentralruf_reply/data/datasources/local_vorgaenge_datasource.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// App-weiter, persistenter Speicher aller Vorgänge — die gemeinsame Klammer,
/// auf die die übrigen Features (Zentralruf-Anfrage, Antwort/Postfach,
/// Word-Ausfüllung, Ablage, Versand) zugreifen, statt dieselben Daten mehrfach
/// zu erfassen. Wird lokal persistiert und beim Start wiederhergestellt; die
/// Antwort des Zentralrufs kommt oft erst Tage nach der Anfrage, ein Neustart
/// darf den Vorgang nicht verlieren.
@lazySingleton
class VorgangCubit extends Cubit<List<Vorgang>> {
  final LocalVorgaengeDatasource _datasource;

  VorgangCubit(this._datasource) : super(const []) {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final gespeichert = await _datasource.loadVorgaenge();
      // Nur setzen, wenn nicht inzwischen schon etwas eingetragen wurde.
      if (state.isEmpty && gespeichert.isNotEmpty) emit(gespeichert);
    } catch (_) {
      // Wiederherstellung ist best-effort; ohne Persistenz startet die
      // Sitzung einfach leer.
    }
  }

  /// Beim Vorausfüllen des Anfrageformulars aufgerufen: legt den Vorgang an
  /// oder aktualisiert (gleiche Referenz erneut angefragt) den Zeitstempel,
  /// ohne bereits erfasste Felder zu verlieren.
  Future<void> registriereAnfrage(
    String referenz, {
    Rechtsgebiet rechtsgebiet = Rechtsgebiet.verkehrsrecht,
    int? mandantId,
    String? mandantName,
  }) async {
    final bereinigt = referenz.trim();
    if (bereinigt.isEmpty) return;

    final bestehend = findeZuReferenz(bereinigt);
    final vorgang = bestehend == null
        ? Vorgang.ausAnfrage(
            referenz: bereinigt,
            angefragtAm: DateTime.now(),
            rechtsgebiet: rechtsgebiet,
            mandantId: mandantId,
            mandantName: mandantName,
          )
        : bestehend.copyWith(
            rechtsgebiet: rechtsgebiet,
            mandantId: mandantId,
            mandantName: mandantName,
          );
    await _upsert(vorgang);
  }

  /// Ordnet eine eingegangene Zentralruf-Antwort über ihre Referenz dem
  /// richtigen Vorgang zu (Req. 3.3) und schaltet ihn auf „beantwortet". Findet
  /// sich keine passende Anfrage, wird ein eigener Vorgang ergänzt.
  Future<void> uebernehmeAntwort(ZentralrufReplyData data) async {
    final referenz = data.referenz?.trim();
    final bestehend = findeZuReferenz(referenz);
    final vorgang = bestehend != null
        ? bestehend.mitAntwort(data)
        : Vorgang.ausAnfrage(
            referenz: referenz?.isNotEmpty == true ? referenz! : '(ohne Referenz)',
            angefragtAm: DateTime.now(),
          ).mitAntwort(data);
    await _upsert(vorgang);
  }

  /// Speichert einen geänderten Vorgang (Upsert über die Referenz).
  Future<void> aktualisiere(Vorgang vorgang) => _upsert(vorgang);

  /// Liefert den Vorgang zur Referenz, falls vorhanden (tolerant gegenüber
  /// Schreibweise und Whitespace).
  Vorgang? findeZuReferenz(String? referenz) {
    if (referenz == null || referenz.trim().isEmpty) return null;
    for (final vorgang in state) {
      if (Vorgang.gleicheReferenz(vorgang.referenz, referenz)) return vorgang;
    }
    return null;
  }

  Future<void> _upsert(Vorgang vorgang) async {
    final neu = [
      ...state.where(
        (vorhanden) =>
            !Vorgang.gleicheReferenz(vorhanden.referenz, vorgang.referenz),
      ),
      vorgang,
    ];
    emit(neu);
    try {
      await _datasource.saveVorgaenge(neu);
    } catch (_) {
      // Persistenz ist best-effort; der In-Memory-Stand bleibt gültig.
    }
  }
}
