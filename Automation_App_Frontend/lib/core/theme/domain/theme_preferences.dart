import 'package:automation_app/core/theme/domain/schriftstufe.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Die beiden Theme-Familien der App. Jede Familie hat einen Hell- und einen
/// Dunkelmodus.
///
/// - [kanzlei]: das Design "Variante A" (warmes Bordeaux-Markenbild mit den
///   Schriften Jost / Source Sans 3 / Source Serif 4). Standard.
/// - [standard]: das ursprüngliche, blaue Material-Theme der App.
enum AppThemeVariant {
  kanzlei,
  standard;

  static AppThemeVariant fromName(String? name) {
    return AppThemeVariant.values.firstWhere(
      (v) => v.name == name,
      orElse: () => AppThemeVariant.kanzlei,
    );
  }
}

/// Persistierte Darstellungs-Einstellungen: gewählte Theme-Familie, der
/// Hell-/Dunkel-/System-Modus und der Schriftgrad. Wird lokal als JSON
/// abgelegt (siehe `ThemePreferencesDatasource`).
@immutable
class ThemePreferences extends Equatable {
  final AppThemeVariant variant;
  final ThemeMode mode;

  /// Der gewählte Schriftgrad (Issue #57). Er liegt hier und nicht neben dem
  /// Theme-Code, weil er dasselbe Schicksal teilt wie Variante und Modus: Der
  /// Anwalt stellt ihn einmal ein und erwartet ihn beim nächsten Start wieder.
  final Schriftstufe schriftstufe;

  const ThemePreferences({
    required this.variant,
    required this.mode,
    this.schriftstufe = Schriftstufe.vorgabe,
  });

  /// Werkseinstellung: Variante A (Kanzlei-Design) im Systemmodus, Schrift
  /// eine Stufe größer.
  static const ThemePreferences defaults = ThemePreferences(
    variant: AppThemeVariant.kanzlei,
    mode: ThemeMode.system,
    schriftstufe: Schriftstufe.vorgabe,
  );

  ThemePreferences copyWith({
    AppThemeVariant? variant,
    ThemeMode? mode,
    Schriftstufe? schriftstufe,
  }) {
    return ThemePreferences(
      variant: variant ?? this.variant,
      mode: mode ?? this.mode,
      schriftstufe: schriftstufe ?? this.schriftstufe,
    );
  }

  Map<String, dynamic> toJson() => {
    'variant': variant.name,
    'mode': mode.name,
    'schriftstufe': schriftstufe.jsonWert,
  };

  /// Liest den Stand zurück, **ohne** auf Vollständigkeit zu bestehen.
  ///
  /// Jede `theme_preferences.json`, die vor Issue #57 geschrieben wurde, hat
  /// den Schlüssel `schriftstufe` nicht. Ein Sturz darüber wäre der teuerste
  /// denkbare Umgang damit: `LocalThemePreferencesDatasource.load` fängt jeden
  /// Fehler ab und fällt auf die Werkseinstellung zurück — die Datei ginge
  /// also nicht kaputt, aber Variante und Modus des Anwalts wären beim ersten
  /// Start nach dem Update trotzdem weg. Fehlender oder unbekannter Wert
  /// heißt deshalb schlicht [Schriftstufe.vorgabe].
  factory ThemePreferences.fromJson(Map<String, dynamic> json) {
    return ThemePreferences(
      variant: AppThemeVariant.fromName(json['variant'] as String?),
      mode: ThemeMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ThemeMode.system,
      ),
      schriftstufe:
          Schriftstufe.ausJson(json['schriftstufe']) ?? Schriftstufe.vorgabe,
    );
  }

  @override
  List<Object?> get props => [variant, mode, schriftstufe];
}
