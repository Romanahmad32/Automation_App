import 'package:automation_app/features/sachgebiete/domain/repositories/sachgebiet_repository.dart';
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_katalog_stand.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// App-weiter Halter des Sachgebietskatalogs (§7.1). Wird beim ersten Zugriff
/// geladen; der Katalog sind Stammdaten und ändern sich zur Laufzeit nicht —
/// einmal geladen genügt für die Sitzung.
///
/// Ein Ladefehler wird als [SachgebietKatalogFehler] gemeldet, nicht
/// verschluckt: Die abhängigen Auswahllisten zeigen dann einen Hinweis mit
/// „Erneut versuchen" und bleiben leer, statt still auf eine eingebaute Liste
/// zurückzufallen (Entscheidung in #70).
@lazySingleton
class SachgebietCubit extends Cubit<SachgebietKatalogStand> {
  final SachgebietRepository _repository;

  SachgebietCubit(this._repository) : super(const SachgebietKatalogLaedt()) {
    ladeErneut();
  }

  Future<void> ladeErneut() async {
    emit(const SachgebietKatalogLaedt());
    try {
      emit(SachgebietKatalogGeladen(await _repository.ladeSachgebiete()));
    } catch (_) {
      emit(const SachgebietKatalogFehler());
    }
  }
}
