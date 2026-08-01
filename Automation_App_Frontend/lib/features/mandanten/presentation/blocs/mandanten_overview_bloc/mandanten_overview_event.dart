part of 'mandanten_overview_bloc.dart';

sealed class MandantenOverviewEvent extends Equatable {
  const MandantenOverviewEvent();

  @override
  List<Object> get props => [];
}

/// Lädt Mandantenregister und Akten-Scan neu.
final class LoadMandantenUebersichtEvent extends MandantenOverviewEvent {}

/// Aktualisiert den Suchfilter. Leerer String zeigt wieder alle Mandanten.
final class SearchMandantenEvent extends MandantenOverviewEvent {
  final String query;

  const SearchMandantenEvent(this.query);

  @override
  List<Object> get props => [query];
}

final class DeleteMandantEvent extends MandantenOverviewEvent {
  final int mandantId;

  const DeleteMandantEvent(this.mandantId);

  @override
  List<Object> get props => [mandantId];
}

/// Ordnet einem bestehenden Mandanten einen noch nicht zugeordneten Ordner zu.
final class VerknuepfeOrdnerEvent extends MandantenOverviewEvent {
  final int mandantId;
  final String ordnername;

  const VerknuepfeOrdnerEvent({
    required this.mandantId,
    required this.ordnername,
  });

  @override
  List<Object> get props => [mandantId, ordnername];
}
