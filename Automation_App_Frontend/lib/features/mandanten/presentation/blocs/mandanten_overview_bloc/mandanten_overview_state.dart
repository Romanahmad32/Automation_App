part of 'mandanten_overview_bloc.dart';

sealed class MandantenOverviewState extends Equatable {
  const MandantenOverviewState();

  @override
  List<Object?> get props => [];
}

final class MandantenOverviewLoading extends MandantenOverviewState {}

final class MandantenOverviewLoaded extends MandantenOverviewState {
  /// Alle Mandanten aus dem Register (ungefiltert, Quelle der Wahrheit).
  final List<Mandant> mandanten;

  /// Alle im Stammordner gefundenen Akten.
  final List<Akte> akten;

  /// Aktueller Suchbegriff. Leer = kein Filter.
  final String query;

  const MandantenOverviewLoaded({
    required this.mandanten,
    required this.akten,
    this.query = '',
  });

  MandantenOverviewLoaded copyWith({
    List<Mandant>? mandanten,
    List<Akte>? akten,
    String? query,
  }) {
    return MandantenOverviewLoaded(
      mandanten: mandanten ?? this.mandanten,
      akten: akten ?? this.akten,
      query: query ?? this.query,
    );
  }

  /// Nach [query] gefilterte Mandanten (Name, Ort oder Ordnername, case-insensitive).
  List<Mandant> get gefilterteMandanten {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return mandanten;
    return mandanten.where((m) {
      if (m.anzeigename.toLowerCase().contains(q)) return true;
      if (m.ort.toLowerCase().contains(q)) return true;
      return m.aktenOrdnernamen.any((o) => o.toLowerCase().contains(q));
    }).toList();
  }

  /// Alle Ordnernamen, die irgendeinem Mandanten zugeordnet sind.
  Set<String> get _zugeordneteOrdner => {
    for (final m in mandanten) ...m.aktenOrdnernamen,
  };

  /// Im Stammordner gefundene Ordner ohne Mandanten-Zuordnung — Kandidaten für
  /// die manuelle Zuordnung.
  List<Akte> get nichtZugeordneteAkten {
    final zugeordnet = _zugeordneteOrdner;
    return akten.where((a) => !zugeordnet.contains(a.ordnername)).toList();
  }

  /// Die zu einem Mandanten gehörenden Akten (über die verknüpften Ordnernamen).
  List<Akte> aktenFuer(Mandant mandant) {
    return akten
        .where((a) => mandant.aktenOrdnernamen.contains(a.ordnername))
        .toList();
  }

  @override
  List<Object?> get props => [mandanten, akten, query];
}

final class MandantenOverviewError extends MandantenOverviewState {
  final String message;

  const MandantenOverviewError(this.message);

  @override
  List<Object?> get props => [message];
}
