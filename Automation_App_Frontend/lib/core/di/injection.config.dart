// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i100;

import 'package:automation_app/core/di/data/datasources/datasource_module.dart'
    as _i332;
import 'package:automation_app/core/general_classes/usecases/use_case.dart'
    as _i223;
import 'package:automation_app/core/network/network_module.dart' as _i194;
import 'package:automation_app/core/router/app_router.dart' as _i842;
import 'package:automation_app/core/theme/data/theme_preferences_datasource.dart'
    as _i1039;
import 'package:automation_app/core/theme/presentation/bloc/theme_bloc.dart'
    as _i1049;
import 'package:automation_app/features/backup/data/datasources/backup_datasource.dart'
    as _i182;
import 'package:automation_app/features/backup/domain/repositories/backup_repository.dart'
    as _i285;
import 'package:automation_app/features/backup/presentation/cubit/backup_cubit.dart'
    as _i198;
import 'package:automation_app/features/dev_simulation/data/datasources/simulation_datasource.dart'
    as _i383;
import 'package:automation_app/features/dev_simulation/domain/repositories/simulation_repository.dart'
    as _i602;
import 'package:automation_app/features/email_versand/data/datasources/email_versand_datasource.dart'
    as _i715;
import 'package:automation_app/features/email_versand/domain/repositories/email_versand_repository.dart'
    as _i67;
import 'package:automation_app/features/email_versand/presentation/blocs/email_entwurf_cubit/email_entwurf_cubit.dart'
    as _i318;
import 'package:automation_app/features/email_versand/presentation/blocs/letzte_versaende_cubit.dart'
    as _i161;
import 'package:automation_app/features/form_template_setup/data/datasources/form_template_datasource.dart'
    as _i308;
import 'package:automation_app/features/form_template_setup/data/datasources/word_template_datasource.dart'
    as _i651;
import 'package:automation_app/features/form_template_setup/data/repositories/form_template_repository_impl.dart'
    as _i963;
import 'package:automation_app/features/form_template_setup/domain/entities/create_form_template_request.dart'
    as _i22;
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart'
    as _i851;
import 'package:automation_app/features/form_template_setup/domain/repositories/form_template_repository.dart'
    as _i211;
import 'package:automation_app/features/form_template_setup/domain/usecases/create_form_template.dart'
    as _i682;
import 'package:automation_app/features/form_template_setup/domain/usecases/delete_form_template.dart'
    as _i60;
import 'package:automation_app/features/form_template_setup/domain/usecases/get_form_templates.dart'
    as _i217;
import 'package:automation_app/features/form_template_setup/domain/usecases/get_template_placeholders.dart'
    as _i818;
import 'package:automation_app/features/form_template_setup/domain/usecases/update_form_template.dart'
    as _i297;
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_data_bloc/form_template_data_bloc.dart'
    as _i347;
import 'package:automation_app/features/form_template_setup/presentation/blocs/form_template_overview_bloc/form_template_overview_bloc.dart'
    as _i244;
import 'package:automation_app/features/form_template_setup/presentation/blocs/template_placeholders_bloc/template_placeholders_bloc.dart'
    as _i702;
import 'package:automation_app/features/mailbox/data/datasources/mailbox_datasource.dart'
    as _i829;
import 'package:automation_app/features/mailbox/data/datasources/mailbox_hub.dart'
    as _i1015;
import 'package:automation_app/features/mailbox/data/repositories/mailbox_repository_impl.dart'
    as _i943;
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_push_notifier.dart'
    as _i579;
import 'package:automation_app/features/mailbox/domain/repositories/mailbox_repository.dart'
    as _i469;
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_auswahl_signal.dart'
    as _i277;
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart'
    as _i865;
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart'
    as _i431;
import 'package:automation_app/features/mandanten/data/datasources/akten_datasource.dart'
    as _i431;
import 'package:automation_app/features/mandanten/data/datasources/import_datei_datasource.dart'
    as _i552;
import 'package:automation_app/features/mandanten/data/datasources/mandant_datasource.dart'
    as _i395;
import 'package:automation_app/features/mandanten/data/datasources/mandanten_import_datasource.dart'
    as _i668;
import 'package:automation_app/features/mandanten/data/datasources/ordner_status_datasource.dart'
    as _i764;
import 'package:automation_app/features/mandanten/data/repositories/mandanten_repository_impl.dart'
    as _i683;
import 'package:automation_app/features/mandanten/domain/entities/ablage_ergebnis.dart'
    as _i10;
import 'package:automation_app/features/mandanten/domain/entities/akte.dart'
    as _i119;
import 'package:automation_app/features/mandanten/domain/entities/create_mandant_request.dart'
    as _i295;
import 'package:automation_app/features/mandanten/domain/entities/fall.dart'
    as _i332;
import 'package:automation_app/features/mandanten/domain/entities/import_bericht.dart'
    as _i659;
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart'
    as _i258;
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart'
    as _i578;
import 'package:automation_app/features/mandanten/domain/entities/mandanten_seite.dart'
    as _i171;
import 'package:automation_app/features/mandanten/domain/entities/ordner_status.dart'
    as _i736;
import 'package:automation_app/features/mandanten/domain/repositories/mandanten_repository.dart'
    as _i763;
import 'package:automation_app/features/mandanten/domain/usecases/create_mandant.dart'
    as _i2;
import 'package:automation_app/features/mandanten/domain/usecases/delete_mandant.dart'
    as _i63;
import 'package:automation_app/features/mandanten/domain/usecases/get_akten.dart'
    as _i965;
import 'package:automation_app/features/mandanten/domain/usecases/get_akten_ordnernamen.dart'
    as _i392;
import 'package:automation_app/features/mandanten/domain/usecases/get_faelle.dart'
    as _i684;
import 'package:automation_app/features/mandanten/domain/usecases/get_mandanten.dart'
    as _i1060;
import 'package:automation_app/features/mandanten/domain/usecases/get_mandanten_seite.dart'
    as _i733;
import 'package:automation_app/features/mandanten/domain/usecases/get_ordner_status.dart'
    as _i482;
import 'package:automation_app/features/mandanten/domain/usecases/importiere_mandanten.dart'
    as _i486;
import 'package:automation_app/features/mandanten/domain/usecases/lege_dokument_ab.dart'
    as _i698;
import 'package:automation_app/features/mandanten/domain/usecases/lies_import_datei.dart'
    as _i675;
import 'package:automation_app/features/mandanten/domain/usecases/setze_ordner_status.dart'
    as _i86;
import 'package:automation_app/features/mandanten/domain/usecases/update_mandant.dart'
    as _i392;
import 'package:automation_app/features/mandanten/domain/usecases/verknuepfe_ordner_mit_mandant.dart'
    as _i443;
import 'package:automation_app/features/mandanten/presentation/blocs/ablage_cubit/ablage_cubit.dart'
    as _i202;
import 'package:automation_app/features/mandanten/presentation/blocs/mandant_edit_cubit/mandant_edit_cubit.dart'
    as _i993;
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_import_cubit/mandanten_import_cubit.dart'
    as _i54;
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_overview_bloc/mandanten_overview_bloc.dart'
    as _i975;
import 'package:automation_app/features/mandanten/presentation/blocs/mandanten_suche_cubit/mandanten_suche_cubit.dart'
    as _i410;
import 'package:automation_app/features/sachgebiete/data/datasources/sachgebiet_datasource.dart'
    as _i460;
import 'package:automation_app/features/sachgebiete/domain/repositories/sachgebiet_repository.dart'
    as _i1069;
import 'package:automation_app/features/sachgebiete/presentation/blocs/sachgebiet_cubit.dart'
    as _i310;
import 'package:automation_app/features/settings/data/datasources/kanzlei_settings_datasource.dart'
    as _i501;
import 'package:automation_app/features/settings/data/repositories/kanzlei_settings_repository_impl.dart'
    as _i366;
import 'package:automation_app/features/settings/domain/entities/kanzlei_settings.dart'
    as _i609;
import 'package:automation_app/features/settings/domain/repositories/kanzlei_settings_repository.dart'
    as _i849;
import 'package:automation_app/features/settings/domain/usecases/erhoehe_auftragsnummer.dart'
    as _i299;
import 'package:automation_app/features/settings/domain/usecases/get_kanzlei_settings.dart'
    as _i706;
import 'package:automation_app/features/settings/domain/usecases/save_kanzlei_settings.dart'
    as _i104;
import 'package:automation_app/features/settings/presentation/blocs/kanzlei_settings_bloc/kanzlei_settings_bloc.dart'
    as _i195;
import 'package:automation_app/features/versicherer/data/datasources/versicherer_datasource.dart'
    as _i315;
import 'package:automation_app/features/versicherer/domain/repositories/versicherer_repository.dart'
    as _i9;
import 'package:automation_app/features/versicherer/presentation/blocs/versicherer_cubit.dart'
    as _i782;
import 'package:automation_app/features/vorgaenge/data/datasources/register_spiegel_datasource.dart'
    as _i412;
import 'package:automation_app/features/vorgaenge/data/datasources/vorgaenge_datasource.dart'
    as _i933;
import 'package:automation_app/features/vorgaenge/domain/repositories/register_spiegel_repository.dart'
    as _i738;
import 'package:automation_app/features/vorgaenge/domain/repositories/vorgang_repository.dart'
    as _i487;
import 'package:automation_app/features/vorgaenge/presentation/blocs/register_spiegel_cubit.dart'
    as _i242;
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart'
    as _i847;
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_navigation_signal.dart'
    as _i416;
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_persistenz_fehler_cubit.dart'
    as _i30;
import 'package:automation_app/features/vorgang_starten/presentation/blocs/vorgang_starten_bloc.dart'
    as _i851;
import 'package:automation_app/features/word_automation/data/datasources/standard_schadenspositionen_datasource.dart'
    as _i50;
import 'package:automation_app/features/word_automation/data/datasources/word_automation_datasource.dart'
    as _i287;
import 'package:automation_app/features/word_automation/data/repositories/word_automation_repository_impl.dart'
    as _i405;
import 'package:automation_app/features/word_automation/domain/entities/arbeitsordner_aufraeumung.dart'
    as _i416;
import 'package:automation_app/features/word_automation/domain/entities/generated_document.dart'
    as _i312;
import 'package:automation_app/features/word_automation/domain/entities/rvg_calculation.dart'
    as _i279;
import 'package:automation_app/features/word_automation/domain/entities/vorlagen_uebersicht.dart'
    as _i382;
import 'package:automation_app/features/word_automation/domain/repositories/standard_schadenspositionen_repository.dart'
    as _i262;
import 'package:automation_app/features/word_automation/domain/repositories/word_automation_repository.dart'
    as _i770;
import 'package:automation_app/features/word_automation/domain/usecases/arbeitsordner_aufraeumen.dart'
    as _i932;
import 'package:automation_app/features/word_automation/domain/usecases/calculate_rvg_fees.dart'
    as _i430;
import 'package:automation_app/features/word_automation/domain/usecases/convert_docx_to_pdf.dart'
    as _i324;
import 'package:automation_app/features/word_automation/domain/usecases/erzeuge_pdf_fassung.dart'
    as _i445;
import 'package:automation_app/features/word_automation/domain/usecases/fill_out_template.dart'
    as _i649;
import 'package:automation_app/features/word_automation/domain/usecases/get_vorlagen_uebersicht.dart'
    as _i250;
import 'package:automation_app/features/word_automation/presentation/blocs/aktive_platzhalter_cubit.dart'
    as _i167;
import 'package:automation_app/features/word_automation/presentation/blocs/document_bloc.dart'
    as _i115;
import 'package:automation_app/features/word_automation/presentation/blocs/edited_document_bloc.dart'
    as _i1040;
import 'package:automation_app/features/word_automation/presentation/blocs/pdf_preview_bloc.dart'
    as _i263;
import 'package:automation_app/features/word_automation/presentation/blocs/rvg_calculation_bloc.dart'
    as _i1026;
import 'package:automation_app/features/word_automation/presentation/blocs/standardpositionen_cubit.dart'
    as _i123;
import 'package:automation_app/features/word_automation/presentation/blocs/wizard_cubit.dart'
    as _i915;
import 'package:automation_app/features/zentralruf_reply/data/datasources/zentralruf_reply_datasource.dart'
    as _i56;
import 'package:automation_app/features/zentralruf_reply/data/repositories/zentralruf_reply_repository_impl.dart'
    as _i853;
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart'
    as _i311;
import 'package:automation_app/features/zentralruf_reply/domain/repositories/zentralruf_reply_repository.dart'
    as _i304;
import 'package:automation_app/features/zentralruf_reply/domain/usecases/parse_zentralruf_reply.dart'
    as _i772;
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart'
    as _i238;
import 'package:automation_app/features/zentralruf_request/data/datasources/zentralruf_datasource.dart'
    as _i615;
import 'package:automation_app/features/zentralruf_request/data/repositories/zentralruf_repository_impl.dart'
    as _i248;
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_prefill_result.dart'
    as _i146;
import 'package:automation_app/features/zentralruf_request/domain/entities/zentralruf_request.dart'
    as _i208;
import 'package:automation_app/features/zentralruf_request/domain/repositories/zentralruf_repository.dart'
    as _i777;
import 'package:automation_app/features/zentralruf_request/domain/usecases/prefill_zentralruf_form.dart'
    as _i239;
import 'package:dio/dio.dart' as _i361;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final datasourceModule = _$DatasourceModule();
    final networkModule = _$NetworkModule();
    await gh.factoryAsync<_i1039.ThemePreferencesDatasource>(
      () => datasourceModule.localThemePreferencesDatasource,
      preResolve: true,
    );
    gh.factory<_i431.FilesystemAktenDatasource>(
      () => const _i431.FilesystemAktenDatasource(),
    );
    gh.singleton<_i361.Dio>(() => networkModule.dio);
    gh.singleton<_i842.AppRouter>(() => _i842.AppRouter());
    gh.lazySingleton<_i277.MailboxAuswahlSignal>(
      () => _i277.MailboxAuswahlSignal(),
    );
    gh.lazySingleton<_i416.VorgangNavigationSignal>(
      () => _i416.VorgangNavigationSignal(),
    );
    gh.lazySingleton<_i30.VorgangPersistenzFehlerCubit>(
      () => _i30.VorgangPersistenzFehlerCubit(),
    );
    gh.factory<_i829.MailboxDatasource>(
      () => _i829.ApiMailboxDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i738.RegisterSpiegelRepository>(
      () => _i412.ApiRegisterSpiegelDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i67.EmailVersandRepository>(
      () => _i715.ApiEmailVersandDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i552.ImportDateiDatasource>(
      () => _i552.FilesystemImportDateiDatasource(),
    );
    gh.factory<_i487.VorgangRepository>(
      () => _i933.ApiVorgaengeDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i9.VersichererRepository>(
      () => _i315.ApiVersichererDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i469.MailboxRepository>(
      () => _i943.MailboxRepositoryImpl(gh<_i829.MailboxDatasource>()),
    );
    gh.factory<_i668.MandantenImportDatasource>(
      () => _i668.ApiMandantenImportDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i56.ZentralrufReplyDatasource>(
      () => _i56.ApiZentralrufReplyDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i395.MandantDatasource>(
      () => _i395.ApiMandantDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i1069.SachgebietRepository>(
      () => _i460.ApiSachgebietDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i764.OrdnerStatusDatasource>(
      () => _i764.ApiOrdnerStatusDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i501.KanzleiSettingsDatasource>(
      () => _i501.ApiKanzleiSettingsDatasource(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i310.SachgebietCubit>(
      () => _i310.SachgebietCubit(gh<_i1069.SachgebietRepository>()),
    );
    gh.factory<_i285.BackupRepository>(
      () => _i182.ApiBackupDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i615.ZentralrufDatasource>(
      () => _i615.ApiZentralrufDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i262.StandardSchadenspositionenRepository>(
      () => _i50.ApiStandardSchadenspositionenDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i287.WordAutomationDatasource>(
      () => _i287.ApiWordAutomationDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i242.RegisterSpiegelCubit>(
      () => _i242.RegisterSpiegelCubit(gh<_i738.RegisterSpiegelRepository>()),
    );
    gh.factory<_i651.WordTemplateDatasource>(
      () => _i651.ApiWordTemplateDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i602.SimulationRepository>(
      () => _i383.ApiSimulationDatasource(gh<_i361.Dio>()),
    );
    gh.factory<_i308.FormTemplateDatasource>(
      () => _i308.ApiFormTemplateDatasource(gh<_i361.Dio>()),
    );
    gh.lazySingleton<_i579.MailboxPushNotifier>(
      () => _i1015.MailboxHub(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i782.VersichererCubit>(
      () => _i782.VersichererCubit(gh<_i9.VersichererRepository>()),
    );
    gh.factory<_i770.WordAutomationRepository>(
      () => _i405.WordAutomationRepositoryImpl(
        gh<_i287.WordAutomationDatasource>(),
      ),
    );
    gh.lazySingleton<_i847.VorgangCubit>(
      () => _i847.VorgangCubit(
        gh<_i487.VorgangRepository>(),
        gh<_i30.VorgangPersistenzFehlerCubit>(),
      ),
    );
    gh.factory<_i849.KanzleiSettingsRepository>(
      () => _i366.KanzleiSettingsRepositoryImpl(
        gh<_i501.KanzleiSettingsDatasource>(),
      ),
    );
    gh.factory<_i304.ZentralrufReplyRepository>(
      () => _i853.ZentralrufReplyRepositoryImpl(
        gh<_i56.ZentralrufReplyDatasource>(),
      ),
    );
    gh.factory<_i763.MandantenRepository>(
      () => _i683.MandantenRepositoryImpl(
        gh<_i395.MandantDatasource>(),
        gh<_i431.FilesystemAktenDatasource>(),
        gh<_i764.OrdnerStatusDatasource>(),
        gh<_i552.ImportDateiDatasource>(),
        gh<_i668.MandantenImportDatasource>(),
        gh<_i849.KanzleiSettingsRepository>(),
      ),
    );
    gh.factory<_i223.UseCase<List<_i119.Akte>, _i223.NoParams>>(
      () => _i965.GetAkten(gh<_i763.MandantenRepository>()),
    );
    gh.singleton<_i1049.ThemeBloc>(
      () => _i1049.ThemeBloc(gh<_i1039.ThemePreferencesDatasource>()),
    );
    gh.factory<_i223.UseCase<void, _i63.DeleteMandantParams>>(
      () => _i63.DeleteMandant(gh<_i763.MandantenRepository>()),
    );
    gh.factory<
      _i223.UseCase<_i659.ImportBericht, _i486.ImportiereMandantenParams>
    >(() => _i486.ImportiereMandanten(gh<_i763.MandantenRepository>()));
    gh.factory<_i123.StandardpositionenCubit>(
      () => _i123.StandardpositionenCubit(
        gh<_i262.StandardSchadenspositionenRepository>(),
      ),
    );
    gh.factory<_i223.UseCase<List<String>, _i223.NoParams>>(
      () => _i392.GetAktenOrdnernamen(gh<_i763.MandantenRepository>()),
    );
    gh.factory<_i223.UseCase<_i258.Mandant, _i258.Mandant>>(
      () => _i392.UpdateMandant(gh<_i763.MandantenRepository>()),
    );
    gh.factory<_i777.ZentralrufRepository>(
      () => _i248.ZentralrufRepositoryImpl(gh<_i615.ZentralrufDatasource>()),
    );
    gh.factory<
      _i223.UseCase<_i578.MandantenImportDatei, _i675.LiesImportDateiParams>
    >(() => _i675.LiesImportDatei(gh<_i763.MandantenRepository>()));
    gh.lazySingleton<_i161.LetzteVersaendeCubit>(
      () => _i161.LetzteVersaendeCubit(gh<_i67.EmailVersandRepository>()),
    );
    gh.factory<_i54.MandantenImportCubit>(
      () => _i54.MandantenImportCubit(
        gh<
          _i223.UseCase<_i578.MandantenImportDatei, _i675.LiesImportDateiParams>
        >(),
        gh<
          _i223.UseCase<_i659.ImportBericht, _i486.ImportiereMandantenParams>
        >(),
      ),
    );
    gh.factory<_i865.MailboxConfigBloc>(
      () => _i865.MailboxConfigBloc(gh<_i469.MailboxRepository>()),
    );
    gh.factory<_i223.UseCase<_i609.KanzleiSettings, _i223.NoParams>>(
      () => _i706.GetKanzleiSettings(gh<_i849.KanzleiSettingsRepository>()),
    );
    gh.factory<_i431.MailboxInboxCubit>(
      () => _i431.MailboxInboxCubit(
        gh<_i469.MailboxRepository>(),
        gh<_i579.MailboxPushNotifier>(),
      ),
    );
    gh.factory<_i223.UseCase<_i609.KanzleiSettings, _i609.KanzleiSettings>>(
      () => _i104.SaveKanzleiSettings(gh<_i849.KanzleiSettingsRepository>()),
    );
    gh.factory<
      _i223.UseCase<_i279.RvgCalculation, _i430.CalculateRvgFeesParams>
    >(
      () => _i430.CalculateRvgFees(
        repository: gh<_i770.WordAutomationRepository>(),
      ),
    );
    gh.factory<_i198.BackupCubit>(
      () => _i198.BackupCubit(gh<_i285.BackupRepository>()),
    );
    gh.factory<_i299.ErhoeheAuftragsnummer>(
      () => _i299.ErhoeheAuftragsnummer(gh<_i849.KanzleiSettingsRepository>()),
    );
    gh.factory<_i223.UseCase<String, _i445.ErzeugePdfFassungParams>>(
      () => _i445.ErzeugePdfFassung(
        repository: gh<_i770.WordAutomationRepository>(),
      ),
    );
    gh.factory<_i1026.RvgCalculationBloc>(
      () => _i1026.RvgCalculationBloc(
        gh<_i223.UseCase<_i279.RvgCalculation, _i430.CalculateRvgFeesParams>>(),
      ),
    );
    gh.factory<_i211.FormTemplateRepository>(
      () => _i963.FormTemplateRepositoryImpl(
        gh<_i308.FormTemplateDatasource>(),
        gh<_i651.WordTemplateDatasource>(),
      ),
    );
    gh.factory<
      _i223.UseCase<
        _i416.ArbeitsordnerAufraeumung,
        _i932.ArbeitsordnerAufraeumenParams
      >
    >(
      () => _i932.ArbeitsordnerAufraeumen(
        repository: gh<_i770.WordAutomationRepository>(),
      ),
    );
    gh.factory<_i223.UseCase<_i382.VorlagenUebersicht, _i223.NoParams>>(
      () => _i250.GetVorlagenUebersicht(
        repository: gh<_i770.WordAutomationRepository>(),
      ),
    );
    gh.factory<_i223.UseCase<_i100.Uint8List, _i324.ConvertDocxToPdfParams>>(
      () => _i324.ConvertDocxToPdf(
        repository: gh<_i770.WordAutomationRepository>(),
      ),
    );
    gh.factory<
      _i223.UseCase<_i312.GeneratedDocument, _i649.FillOutTemplateParams>
    >(
      () => _i649.FillOutTemplate(
        repository: gh<_i770.WordAutomationRepository>(),
      ),
    );
    gh.factory<
      _i223.UseCase<
        _i311.ZentralrufReplyParseResult,
        _i311.ZentralrufReplyInput
      >
    >(
      () => _i772.ParseZentralrufReply(
        repository: gh<_i304.ZentralrufReplyRepository>(),
      ),
    );
    gh.factory<_i223.UseCase<_i258.Mandant, _i295.CreateMandantRequest>>(
      () => _i2.CreateMandant(gh<_i763.MandantenRepository>()),
    );
    gh.factory<_i195.KanzleiSettingsBloc>(
      () => _i195.KanzleiSettingsBloc(
        gh<_i223.UseCase<_i609.KanzleiSettings, _i223.NoParams>>(),
        gh<_i223.UseCase<_i609.KanzleiSettings, _i609.KanzleiSettings>>(),
      ),
    );
    gh.factory<_i223.UseCase<void, _i22.CreateFormTemplateRequest>>(
      () => _i682.CreateFormTemplate(gh<_i211.FormTemplateRepository>()),
    );
    gh.factory<_i223.UseCase<List<_i851.FormTemplate>, _i223.NoParams>>(
      () => _i217.GetFormTemplates(gh<_i211.FormTemplateRepository>()),
    );
    gh.factory<_i223.UseCase<List<_i332.Fall>, _i684.GetFaelleParams>>(
      () => _i684.GetFaelle(gh<_i763.MandantenRepository>()),
    );
    gh.factory<
      _i223.UseCase<_i146.ZentralrufPrefillResult, _i208.ZentralrufRequest>
    >(
      () => _i239.PrefillZentralrufForm(
        repository: gh<_i777.ZentralrufRepository>(),
      ),
    );
    gh.factory<
      _i223.UseCase<List<_i736.OrdnerStatus>, _i86.SetzeOrdnerStatusParams>
    >(() => _i86.SetzeOrdnerStatus(gh<_i763.MandantenRepository>()));
    gh.factory<_i223.UseCase<_i10.AblageErgebnis, _i763.LegeDokumentAbParams>>(
      () => _i698.LegeDokumentAb(gh<_i763.MandantenRepository>()),
    );
    gh.factory<_i223.UseCase<List<_i258.Mandant>, _i223.NoParams>>(
      () => _i1060.GetMandanten(gh<_i763.MandantenRepository>()),
    );
    gh.factory<
      _i223.UseCase<List<String>, _i818.GetTemplatePlaceholdersParams>
    >(() => _i818.GetTemplatePlaceholders(gh<_i211.FormTemplateRepository>()));
    gh.factory<_i223.UseCase<_i171.MandantenSeite, _i733.MandantenSeiteParams>>(
      () => _i733.GetMandantenSeite(gh<_i763.MandantenRepository>()),
    );
    gh.factory<
      _i223.UseCase<_i851.FormTemplate, _i297.UpdateFormTemplateParams>
    >(() => _i297.UpdateFormTemplate(gh<_i211.FormTemplateRepository>()));
    gh.factory<_i223.UseCase<_i258.Mandant, _i443.VerknuepfeOrdnerParams>>(
      () => _i443.VerknuepfeOrdnerMitMandant(gh<_i763.MandantenRepository>()),
    );
    gh.factory<_i223.UseCase<List<_i736.OrdnerStatus>, _i223.NoParams>>(
      () => _i482.GetOrdnerStatus(gh<_i763.MandantenRepository>()),
    );
    gh.factory<_i115.DocumentBloc>(
      () => _i115.DocumentBloc(
        gh<_i223.UseCase<_i382.VorlagenUebersicht, _i223.NoParams>>(),
      ),
    );
    gh.factory<_i202.AblageCubit>(
      () => _i202.AblageCubit(
        gh<_i223.UseCase<List<_i258.Mandant>, _i223.NoParams>>(),
        gh<_i223.UseCase<List<_i119.Akte>, _i223.NoParams>>(),
        gh<_i223.UseCase<List<_i332.Fall>, _i684.GetFaelleParams>>(),
        gh<_i223.UseCase<_i258.Mandant, _i295.CreateMandantRequest>>(),
        gh<_i223.UseCase<_i10.AblageErgebnis, _i763.LegeDokumentAbParams>>(),
        gh<_i849.KanzleiSettingsRepository>(),
      ),
    );
    gh.factory<_i1040.EditedDocumentBloc>(
      () => _i1040.EditedDocumentBloc(
        gh<
          _i223.UseCase<_i312.GeneratedDocument, _i649.FillOutTemplateParams>
        >(),
      ),
    );
    gh.factory<_i223.UseCase<void, _i60.DeleteFormTemplateParams>>(
      () => _i60.DeleteFormTemplate(gh<_i211.FormTemplateRepository>()),
    );
    gh.factory<_i851.VorgangStartenBloc>(
      () => _i851.VorgangStartenBloc(
        gh<
          _i223.UseCase<_i146.ZentralrufPrefillResult, _i208.ZentralrufRequest>
        >(),
        gh<_i223.UseCase<_i609.KanzleiSettings, _i223.NoParams>>(),
        gh<_i223.UseCase<_i258.Mandant, _i295.CreateMandantRequest>>(),
        gh<_i223.UseCase<_i258.Mandant, _i258.Mandant>>(),
        gh<_i847.VorgangCubit>(),
      ),
    );
    gh.factory<_i238.ZentralrufReplyBloc>(
      () => _i238.ZentralrufReplyBloc(
        gh<
          _i223.UseCase<
            _i311.ZentralrufReplyParseResult,
            _i311.ZentralrufReplyInput
          >
        >(),
      ),
    );
    gh.factory<_i410.MandantenSucheCubit>(
      () => _i410.MandantenSucheCubit(
        gh<_i223.UseCase<_i171.MandantenSeite, _i733.MandantenSeiteParams>>(),
      ),
    );
    gh.factory<_i318.EmailEntwurfCubit>(
      () => _i318.EmailEntwurfCubit(
        gh<_i67.EmailVersandRepository>(),
        gh<_i223.UseCase<_i609.KanzleiSettings, _i223.NoParams>>(),
        gh<_i223.UseCase<List<_i258.Mandant>, _i223.NoParams>>(),
        gh<_i782.VersichererCubit>(),
      ),
    );
    gh.factory<_i263.TemplatePdfPreviewBloc>(
      () => _i263.TemplatePdfPreviewBloc(
        gh<_i223.UseCase<_i100.Uint8List, _i324.ConvertDocxToPdfParams>>(),
      ),
    );
    gh.factory<_i263.ResultPdfPreviewBloc>(
      () => _i263.ResultPdfPreviewBloc(
        gh<_i223.UseCase<_i100.Uint8List, _i324.ConvertDocxToPdfParams>>(),
      ),
    );
    gh.lazySingleton<_i244.FormTemplateOverviewBloc>(
      () => _i244.FormTemplateOverviewBloc(
        gh<_i223.UseCase<List<_i851.FormTemplate>, _i223.NoParams>>(),
        gh<_i223.UseCase<void, _i60.DeleteFormTemplateParams>>(),
      ),
    );
    gh.factory<_i702.TemplatePlaceholdersBloc>(
      () => _i702.TemplatePlaceholdersBloc(
        gh<_i223.UseCase<List<String>, _i818.GetTemplatePlaceholdersParams>>(),
      ),
    );
    gh.factory<_i167.AktivePlatzhalterCubit>(
      () => _i167.AktivePlatzhalterCubit(
        gh<_i223.UseCase<List<String>, _i818.GetTemplatePlaceholdersParams>>(),
      ),
    );
    gh.factory<_i975.MandantenOverviewBloc>(
      () => _i975.MandantenOverviewBloc(
        gh<_i223.UseCase<_i171.MandantenSeite, _i733.MandantenSeiteParams>>(),
        gh<_i223.UseCase<List<String>, _i223.NoParams>>(),
        gh<_i223.UseCase<List<_i119.Akte>, _i223.NoParams>>(),
        gh<_i223.UseCase<List<_i332.Fall>, _i684.GetFaelleParams>>(),
        gh<_i223.UseCase<List<_i736.OrdnerStatus>, _i223.NoParams>>(),
        gh<
          _i223.UseCase<List<_i736.OrdnerStatus>, _i86.SetzeOrdnerStatusParams>
        >(),
        gh<_i223.UseCase<void, _i63.DeleteMandantParams>>(),
        gh<_i223.UseCase<_i258.Mandant, _i443.VerknuepfeOrdnerParams>>(),
      ),
    );
    gh.factory<_i993.MandantEditCubit>(
      () => _i993.MandantEditCubit(
        gh<_i223.UseCase<_i258.Mandant, _i295.CreateMandantRequest>>(),
        gh<_i223.UseCase<_i258.Mandant, _i258.Mandant>>(),
      ),
    );
    gh.factory<_i347.FormTemplateDataBloc>(
      () => _i347.FormTemplateDataBloc(
        gh<_i223.UseCase<void, _i22.CreateFormTemplateRequest>>(),
        gh<_i223.UseCase<_i851.FormTemplate, _i297.UpdateFormTemplateParams>>(),
      ),
    );
    gh.factory<_i915.WizardCubit>(
      () => _i915.WizardCubit(
        gh<_i223.UseCase<_i851.FormTemplate, _i297.UpdateFormTemplateParams>>(),
        gh<_i223.UseCase<List<_i258.Mandant>, _i223.NoParams>>(),
        gh<_i847.VorgangCubit>(),
      ),
    );
    return this;
  }
}

class _$DatasourceModule extends _i332.DatasourceModule {}

class _$NetworkModule extends _i194.NetworkModule {}
