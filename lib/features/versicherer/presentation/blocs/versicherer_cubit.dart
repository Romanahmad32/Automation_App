import 'package:automation_app/features/versicherer/domain/entities/versicherer.dart';
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// App-weiter Cache der Versicherer-Wissensbasis. Wird beim ersten Zugriff
/// geladen; ein Ladefehler ist unkritisch (dann bleibt die Liste leer und die
/// abhängigen Komfortfunktionen — Lückenfüllung, Auswahl bei Negativ-Antworten —
/// entfallen still), daher keine Fehler-Snackbar wie beim [VorgangCubit].
@lazySingleton
class VersichererCubit extends Cubit<List<Versicherer>> {
  final VersichererRepository _repository;

  VersichererCubit(this._repository) : super(const []) {
    ladeErneut();
  }

  /// Lädt das Register (neu) — z. B. nachdem eine Antwort geparst wurde und
  /// das Backend daraus gelernt haben kann.
  Future<void> ladeErneut() async {
    try {
      emit(await _repository.ladeVersicherer());
    } catch (_) {
      // Bewusst still: die Wissensbasis ist ein Komfort, kein Pflichtbestandteil.
    }
  }

  /// Liefert den Eintrag zum Namen (normalisierter Vergleich), falls bekannt.
  Versicherer? findeZuName(String? name) {
    final gesucht = _normalisiere(name);
    if (gesucht == null) return null;
    for (final versicherer in state) {
      if (_normalisiere(versicherer.name) == gesucht) return versicherer;
    }
    return null;
  }

  static String? _normalisiere(String? name) {
    final bereinigt = name?.trim().toUpperCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return (bereinigt == null || bereinigt.isEmpty) ? null : bereinigt;
  }
}
