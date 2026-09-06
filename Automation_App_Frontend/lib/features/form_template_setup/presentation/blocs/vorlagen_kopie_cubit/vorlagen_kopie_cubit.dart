import 'package:automation_app/core/general_classes/usecases/use_case.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart';
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart';
import 'package:automation_app/features/form_template_setup/domain/services/gespeicherter_stand.dart';
import 'package:automation_app/features/form_template_setup/domain/services/kopie_name.dart';
import 'package:automation_app/features/form_template_setup/presentation/blocs/vorlagen_kopie_cubit/vorlagen_kopie_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

export 'package:automation_app/features/form_template_setup/presentation/blocs/vorlagen_kopie_cubit/vorlagen_kopie_state.dart';

/// „Duplizieren" in der Vorlagenübersicht (#104 Stufe 4) — eine Handlung, ein
/// Cubit.
///
/// **Warum nicht im `FormTemplateOverviewBloc`:** Der ist ein
/// `@lazySingleton`, den sich die Vorlagenverwaltung mit dem Wizard-Dropdown
/// in „Word Automation" teilt (siehe `FALLSTRICKE.md`, „Zustand"). Sein
/// Fehlerzustand `FormTemplateOverviewError` **ersetzt** die geladene Liste;
/// ein Namenskonflikt beim Duplizieren würde dem Wizard also die Vorlagenwahl
/// wegnehmen, mitten im Ausfüllen. Dazu käme eine dritte Abhängigkeit im
/// Konstruktor eines Blocs, den zwei Features anfassen. Der Overview-Bloc
/// bleibt deshalb, was er ist — lesen und löschen — und lädt nach einer
/// erfolgreichen Kopie schlicht neu, wie nach dem Anlegen auch.
///
/// **Kein neuer Endpunkt:** Die Kopie geht über den vorhandenen Anlege-Weg
/// (`CreateFormTemplate` → `POST /api/FormTemplates`). Damit gilt für sie
/// dieselbe Fehlerbehandlung wie fürs Anlegen, einschließlich der
/// Namens-Dublette (409), die der Dienst erzwingt.
@injectable
class VorlagenKopieCubit extends Cubit<VorlagenKopieState> {
  final UseCase<void, CreateFormTemplateRequest> _createFormTemplate;

  VorlagenKopieCubit(this._createFormTemplate)
    : super(const VorlagenKopieRuht());

  /// Legt eine Kopie von [original] an. [vorhandeneNamen] ist der **geladene**
  /// Bestand der Übersicht; daraus findet [KopieName] einen freien Namen.
  ///
  /// Kopiert wird alles, was ein Feld trägt (Name, Typ, Datenquelle, Pflicht,
  /// Vorbelegung), **nicht** aber die Word-Dateien: Zwei Vorlagen auf derselben
  /// Datei wären zwei Beschreibungen desselben Dokuments — wer dupliziert,
  /// will die Feldarbeit wiederverwenden, nicht die Datei doppelt verknüpfen.
  /// Die Kopie ist damit unvollständig, und genau das steht in ihrem Stand:
  /// `vollstaendig: false`, `offen: 0` — ohne Datei sind keine Platzhalter
  /// bekannt, es ist also nichts zu zählen (siehe
  /// [GespeicherterStand.ohneDatei]).
  Future<void> dupliziere(
    FormTemplate original, {
    required Iterable<String> vorhandeneNamen,
  }) async {
    if (state is VorlagenKopieLaeuft) return;
    final name = KopieName.fuer(original.templateName, vorhandeneNamen);
    emit(const VorlagenKopieLaeuft());

    final ergebnis = await _createFormTemplate(
      CreateFormTemplateRequest(
        templateName: name,
        // Dieselben Feldobjekte: `FieldData` ist unveränderlich, eine Kopie
        // hier brächte nur eine zweite Stelle, die bei einem neuen Feldattribut
        // nachzuziehen wäre.
        fields: original.fields,
        stand: GespeicherterStand.ohneDatei,
      ),
    );
    if (isClosed) return;

    switch (ergebnis) {
      case Right():
        emit(VorlagenKopieErfolg(name));
      case Left(value: final fehler):
        emit(VorlagenKopieFehler(fehler.message));
    }
    if (isClosed) return;
    emit(const VorlagenKopieRuht());
  }
}
