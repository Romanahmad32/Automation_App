import 'dart:async';
import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart';
import 'package:automation_app/features/mailbox/domain/repositories/posteingang_repository.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

@injectable
class PosteingangCubit extends Cubit<PosteingangState> {
  final PosteingangRepository _repository;
  final List<String?> _verlauf = [];
  String? _cursor;
  int _seitenAnfrage = 0;
  int _inhaltAnfrage = 0;
  StreamSubscription<void>? _push;
  Timer? _entprellung;

  PosteingangCubit(this._repository, MailboxPushNotifier hub)
    : super(const PosteingangState()) {
    _push = hub.onPosteingangChanged.listen((_) {
      _entprellung?.cancel();
      _entprellung = Timer(const Duration(seconds: 1), () {
        if (isClosed) return;
        if (!state.laedt && state.auswahl == null && _cursor == null) {
          aktualisieren();
        } else {
          emit(state.copyWith(neueNachrichten: true));
        }
      });
    });
    hub.ensureConnected();
  }

  Future<void> aktualisieren() => _lade(null, []);

  Future<void> aeltere() async {
    final cursor = state.seite?.naechsteSeite;
    if (state.laedt || cursor == null) return;
    await _lade(cursor, [..._verlauf, _cursor]);
  }

  Future<void> neuere() async {
    if (state.laedt || _verlauf.isEmpty) return;
    await _lade(_verlauf.last, _verlauf.take(_verlauf.length - 1).toList());
  }

  Future<void> _lade(String? cursor, List<String?> verlauf) async {
    final anfrage = ++_seitenAnfrage;
    ++_inhaltAnfrage;
    _repository.abbrechen();
    emit(
      state.copyWith(
        laedt: true,
        leereFehler: true,
        leereAuswahl: true,
        inhaltLaedt: false,
      ),
    );
    try {
      final seite = await _repository.ladeSeite(cursor: cursor);
      if (isClosed || anfrage != _seitenAnfrage) return;
      _cursor = cursor;
      _verlauf
        ..clear()
        ..addAll(verlauf);
      emit(PosteingangState(seite: seite, seitennummer: verlauf.length + 1));
    } catch (error) {
      if (!isClosed && anfrage == _seitenAnfrage) {
        emit(state.copyWith(laedt: false, fehler: _meldung(error)));
      }
    }
  }

  Future<void> oeffnen(PosteingangEintrag mail) async {
    if (state.laedt) return;
    final anfrage = ++_inhaltAnfrage;
    emit(state.copyWith(auswahl: mail, leereInhalt: true, inhaltLaedt: true));
    try {
      final inhalt = await _repository.ladeInhalt(mail.id);
      if (!isClosed && anfrage == _inhaltAnfrage) {
        emit(state.copyWith(inhalt: inhalt, inhaltLaedt: false));
      }
    } catch (error) {
      if (!isClosed && anfrage == _inhaltAnfrage) {
        emit(state.copyWith(inhaltLaedt: false, inhaltFehler: _meldung(error)));
      }
    }
  }

  String _meldung(Object error) => error is PosteingangFehler
      ? error.meldung
      : 'Die Nachrichten konnten nicht geladen werden. Bitte erneut versuchen.';

  @override
  Future<void> close() {
    _entprellung?.cancel();
    _push?.cancel();
    _repository.abbrechen();
    return super.close();
  }
}
