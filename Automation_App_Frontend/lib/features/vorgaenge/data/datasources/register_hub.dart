import 'dart:async';

import 'package:automation_app/core/backend/backend_endpoint.dart';
import 'package:automation_app/features/vorgaenge/domain/repositories/register_push_notifier.dart';
import 'package:injectable/injectable.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Push-Anbindung an den Register-Spiegel des Backends (`/hubs/register`),
/// nach demselben Muster wie `MailboxHub` (`mailbox/data/datasources/mailbox_hub.dart`)
/// — eigener Hub, weil das Register ein anderer senkrechter Schnitt ist als
/// das Postfach.
///
/// Anders als beim Postfach trägt die Meldung hier schon die Nutzdaten
/// (`registerPdfFertig` liefert `fertig`/`pdfPfad`/`fehler`, camelCase wie
/// jede andere Antwort des Backends): Ein Nachladen wie beim Postfach
/// bräuchte den ganzen Zeilenbestand nur für einen Satz in der Spiegelleiste.
///
/// Push ist best-effort: Schlägt der Verbindungsaufbau fehl, bleibt die
/// Anzeige beim zuletzt per REST geladenen Stand
/// (`RegisterSpiegelCubit.ladeStand`).
@LazySingleton(as: RegisterPushNotifier)
class RegisterHub implements RegisterPushNotifier {
  static const _url = BackendEndpoint.registerHubUrl;

  HubConnection? _connection;
  Future<void>? _starting;

  final _pdfFertig =
      StreamController<
        ({bool fertig, String? pdfPfad, String? fehler})
      >.broadcast();

  @override
  Stream<({bool fertig, String? pdfPfad, String? fehler})> get onPdfFertig =>
      _pdfFertig.stream;

  @override
  Future<void> ensureConnected() {
    if (_connection != null) return Future.value();
    return _starting ??= _connect();
  }

  Future<void> _connect() async {
    final connection = HubConnectionBuilder()
        .withUrl(_url)
        .withAutomaticReconnect()
        .build();

    connection.on('registerPdfFertig', _pdfFertigEmpfangen);

    try {
      await connection.start();
      _connection = connection;
    } catch (_) {
      // Best-effort: ohne Push bleibt die Anzeige beim zuletzt geladenen Stand.
      _starting = null;
    }
  }

  /// `arguments` ist ein Argument, das eine JSON-Nachbildung von
  /// `RegisterHub.PdfMeldung` trägt — dieselben Feldnamen wie
  /// `RegisterSpiegelDto` (`fertig`, `pdfPfad`, `fehler`).
  void _pdfFertigEmpfangen(List<Object?>? arguments) {
    if (_pdfFertig.isClosed) return;
    final meldung = arguments?.isNotEmpty ?? false
        ? arguments!.first as Map<String, dynamic>?
        : null;
    if (meldung == null) return;
    _pdfFertig.add((
      fertig: meldung['fertig'] as bool? ?? false,
      pdfPfad: meldung['pdfPfad'] as String?,
      fehler: meldung['fehler'] as String?,
    ));
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    await _connection?.stop();
    await _pdfFertig.close();
  }
}
