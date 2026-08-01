import 'dart:io';

import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart';
import 'package:automation_app/features/backup/presentation/cubit/backup_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

/// Steuert Export und Import der Datenbank und meldet Fortschritt bzw. Ergebnis
/// an die Datensicherungs-Ansicht. Die Auswahl der Dateipfade (native Dialoge)
/// bleibt in der UI; hier liegt nur die Orchestrierung mit dem Backend.
@injectable
class BackupCubit extends Cubit<BackupState> {
  final BackupRepository _datasource;

  BackupCubit(this._datasource) : super(const BackupIdle());

  /// Holt die Sicherung vom Backend und schreibt sie an den gewählten Zielpfad.
  Future<void> exportiere(String zielPfad) async {
    emit(const BackupBusy('Sicherung wird erstellt …'));
    try {
      final bytes = await _datasource.exportDatenbank();
      await File(zielPfad).writeAsBytes(bytes, flush: true);
      emit(BackupErfolg('Sicherung gespeichert unter:\n$zielPfad'));
    } on DioException catch (e) {
      emit(BackupFehler(_fehlertext(e, 'Export fehlgeschlagen')));
    } catch (e) {
      emit(BackupFehler('Export fehlgeschlagen: $e'));
    }
  }

  /// Spielt die gewählte Sicherungsdatei ein (überschreibt alle Daten).
  Future<void> importiere(String dateipfad) async {
    emit(const BackupBusy('Sicherung wird eingespielt …'));
    try {
      final meldung = await _datasource.importDatenbank(dateipfad);
      emit(BackupErfolg(meldung));
    } on DioException catch (e) {
      emit(BackupFehler(_fehlertext(e, 'Import fehlgeschlagen')));
    } catch (e) {
      emit(BackupFehler('Import fehlgeschlagen: $e'));
    }
  }

  String _fehlertext(DioException e, String prefix) {
    final data = e.response?.data;
    // Das Backend liefert bei ungültiger Sicherung eine 400 mit Klartext-Grund.
    if (data is String && data.trim().isNotEmpty) return data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return '$prefix: ${e.message ?? 'Verbindungsfehler'}';
  }
}
