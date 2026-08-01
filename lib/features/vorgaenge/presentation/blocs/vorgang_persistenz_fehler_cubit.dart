import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// App-weiter Kanal für fehlgeschlagene Vorgangs-Persistenz. Der [VorgangCubit]
/// meldet Fehler hierher, statt sie still zu schlucken; die Shell zeigt sie als
/// Snackbar mit „Erneut versuchen" an (siehe VorgangPersistenzFehlerListener).
/// Eigener Cubit statt eines Fehlerfelds im Vorgangs-State, damit die vielen
/// bestehenden Konsumenten der Vorgangsliste unverändert bleiben.
@lazySingleton
class VorgangPersistenzFehlerCubit extends Cubit<VorgangPersistenzFehler?> {
  VorgangPersistenzFehlerCubit() : super(null);

  void melde(VorgangPersistenzFehler fehler) => emit(fehler);

  /// Setzt den Kanal zurück, nachdem der Fehler angezeigt/behandelt wurde.
  void quittiere() => emit(null);
}
