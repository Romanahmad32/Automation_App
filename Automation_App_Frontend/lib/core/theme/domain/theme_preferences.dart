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

/// Persistierte Darstellungs-Einstellungen: gewählte Theme-Familie und der
/// Hell-/Dunkel-/System-Modus. Wird lokal als JSON abgelegt (siehe
/// `LocalThemePreferencesDatasource`).
@immutable
class ThemePreferences extends Equatable {
  final AppThemeVariant variant;
  final ThemeMode mode;

  const ThemePreferences({required this.variant, required this.mode});

  /// Werkseinstellung: Variante A (Kanzlei-Design) im Systemmodus.
  static const ThemePreferences defaults = ThemePreferences(
    variant: AppThemeVariant.kanzlei,
    mode: ThemeMode.system,
  );

  ThemePreferences copyWith({AppThemeVariant? variant, ThemeMode? mode}) {
    return ThemePreferences(
      variant: variant ?? this.variant,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() => {'variant': variant.name, 'mode': mode.name};

  factory ThemePreferences.fromJson(Map<String, dynamic> json) {
    return ThemePreferences(
      variant: AppThemeVariant.fromName(json['variant'] as String?),
      mode: ThemeMode.values.firstWhere(
        (m) => m.name == json['mode'],
        orElse: () => ThemeMode.system,
      ),
    );
  }

  @override
  List<Object?> get props => [variant, mode];
}
