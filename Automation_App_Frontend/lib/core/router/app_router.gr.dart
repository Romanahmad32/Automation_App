// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:auto_route/auto_route.dart' as _i18;
import 'package:automation_app/core/general_widgets/drawer/app_shell_page.dart'
    as _i1;
import 'package:automation_app/features/dashboard/presentation/pages/dashboard_page.dart'
    as _i2;
import 'package:automation_app/features/form_template_setup/domain/entities/form_template.dart'
    as _i20;
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_details_page.dart'
    as _i3;
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_management_page.dart'
    as _i4;
import 'package:automation_app/features/form_template_setup/presentation/pages/form_template_management_stack_page.dart'
    as _i5;
import 'package:automation_app/features/mailbox/presentation/pages/mailbox_inbox_page.dart'
    as _i6;
import 'package:automation_app/features/mandanten/domain/entities/mandant.dart'
    as _i21;
import 'package:automation_app/features/mandanten/domain/entities/mandanten_import_datei.dart'
    as _i22;
import 'package:automation_app/features/mandanten/presentation/pages/mandant_details_page.dart'
    as _i7;
import 'package:automation_app/features/mandanten/presentation/pages/mandanten_import_page.dart'
    as _i8;
import 'package:automation_app/features/mandanten/presentation/pages/mandanten_overview_page.dart'
    as _i9;
import 'package:automation_app/features/mandanten/presentation/pages/mandanten_stack_page.dart'
    as _i10;
import 'package:automation_app/features/mandanten/presentation/pages/nicht_zugeordnete_ordner_page.dart'
    as _i11;
import 'package:automation_app/features/register_import/presentation/pages/register_import_page.dart'
    as _i12;
import 'package:automation_app/features/settings/presentation/pages/settings_page.dart'
    as _i14;
import 'package:automation_app/features/vorgaenge/presentation/pages/register_page.dart'
    as _i13;
import 'package:automation_app/features/vorgaenge/presentation/pages/vorgaenge_verwalten_page.dart'
    as _i15;
import 'package:automation_app/features/vorgang_starten/presentation/pages/vorgang_starten_page.dart'
    as _i16;
import 'package:automation_app/features/word_automation/presentation/pages/word_automation_page.dart'
    as _i17;
import 'package:flutter/material.dart' as _i19;

/// generated route for
/// [_i1.AppShellPage]
class AppShellRoute extends _i18.PageRouteInfo<void> {
  const AppShellRoute({List<_i18.PageRouteInfo>? children})
    : super(AppShellRoute.name, initialChildren: children);

  static const String name = 'AppShellRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return const _i1.AppShellPage();
    },
  );
}

/// generated route for
/// [_i2.DashboardPage]
class DashboardRoute extends _i18.PageRouteInfo<void> {
  const DashboardRoute({List<_i18.PageRouteInfo>? children})
    : super(DashboardRoute.name, initialChildren: children);

  static const String name = 'DashboardRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i2.DashboardPage());
    },
  );
}

/// generated route for
/// [_i3.FormTemplateDetailsPage]
class FormTemplateDetailsRoute
    extends _i18.PageRouteInfo<FormTemplateDetailsRouteArgs> {
  FormTemplateDetailsRoute({
    _i19.Key? key,
    _i20.FormTemplate? formTemplate,
    List<_i18.PageRouteInfo>? children,
  }) : super(
         FormTemplateDetailsRoute.name,
         args: FormTemplateDetailsRouteArgs(
           key: key,
           formTemplate: formTemplate,
         ),
         initialChildren: children,
       );

  static const String name = 'FormTemplateDetailsRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FormTemplateDetailsRouteArgs>(
        orElse: () => const FormTemplateDetailsRouteArgs(),
      );
      return _i18.WrappedRoute(
        child: _i3.FormTemplateDetailsPage(
          key: args.key,
          formTemplate: args.formTemplate,
        ),
      );
    },
  );
}

class FormTemplateDetailsRouteArgs {
  const FormTemplateDetailsRouteArgs({this.key, this.formTemplate});

  final _i19.Key? key;

  final _i20.FormTemplate? formTemplate;

  @override
  String toString() {
    return 'FormTemplateDetailsRouteArgs{key: $key, formTemplate: $formTemplate}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FormTemplateDetailsRouteArgs) return false;
    return key == other.key && formTemplate == other.formTemplate;
  }

  @override
  int get hashCode => key.hashCode ^ formTemplate.hashCode;
}

/// generated route for
/// [_i4.FormTemplateManagementPage]
class FormTemplateManagementRoute extends _i18.PageRouteInfo<void> {
  const FormTemplateManagementRoute({List<_i18.PageRouteInfo>? children})
    : super(FormTemplateManagementRoute.name, initialChildren: children);

  static const String name = 'FormTemplateManagementRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i4.FormTemplateManagementPage());
    },
  );
}

/// generated route for
/// [_i5.FormTemplateManagementStackPage]
class FormTemplateManagementStackRoute extends _i18.PageRouteInfo<void> {
  const FormTemplateManagementStackRoute({List<_i18.PageRouteInfo>? children})
    : super(FormTemplateManagementStackRoute.name, initialChildren: children);

  static const String name = 'FormTemplateManagementStackRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return const _i5.FormTemplateManagementStackPage();
    },
  );
}

/// generated route for
/// [_i6.MailboxInboxPage]
class MailboxInboxRoute extends _i18.PageRouteInfo<void> {
  const MailboxInboxRoute({List<_i18.PageRouteInfo>? children})
    : super(MailboxInboxRoute.name, initialChildren: children);

  static const String name = 'MailboxInboxRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i6.MailboxInboxPage());
    },
  );
}

/// generated route for
/// [_i7.MandantDetailsPage]
class MandantDetailsRoute extends _i18.PageRouteInfo<MandantDetailsRouteArgs> {
  MandantDetailsRoute({
    _i19.Key? key,
    _i21.Mandant? mandant,
    String? vorbelegterOrdner,
    String? vorbelegterVorname,
    String? vorbelegterNachname,
    List<_i18.PageRouteInfo>? children,
  }) : super(
         MandantDetailsRoute.name,
         args: MandantDetailsRouteArgs(
           key: key,
           mandant: mandant,
           vorbelegterOrdner: vorbelegterOrdner,
           vorbelegterVorname: vorbelegterVorname,
           vorbelegterNachname: vorbelegterNachname,
         ),
         initialChildren: children,
       );

  static const String name = 'MandantDetailsRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MandantDetailsRouteArgs>(
        orElse: () => const MandantDetailsRouteArgs(),
      );
      return _i18.WrappedRoute(
        child: _i7.MandantDetailsPage(
          key: args.key,
          mandant: args.mandant,
          vorbelegterOrdner: args.vorbelegterOrdner,
          vorbelegterVorname: args.vorbelegterVorname,
          vorbelegterNachname: args.vorbelegterNachname,
        ),
      );
    },
  );
}

class MandantDetailsRouteArgs {
  const MandantDetailsRouteArgs({
    this.key,
    this.mandant,
    this.vorbelegterOrdner,
    this.vorbelegterVorname,
    this.vorbelegterNachname,
  });

  final _i19.Key? key;

  final _i21.Mandant? mandant;

  final String? vorbelegterOrdner;

  final String? vorbelegterVorname;

  final String? vorbelegterNachname;

  @override
  String toString() {
    return 'MandantDetailsRouteArgs{key: $key, mandant: $mandant, vorbelegterOrdner: $vorbelegterOrdner, vorbelegterVorname: $vorbelegterVorname, vorbelegterNachname: $vorbelegterNachname}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MandantDetailsRouteArgs) return false;
    return key == other.key &&
        mandant == other.mandant &&
        vorbelegterOrdner == other.vorbelegterOrdner &&
        vorbelegterVorname == other.vorbelegterVorname &&
        vorbelegterNachname == other.vorbelegterNachname;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      mandant.hashCode ^
      vorbelegterOrdner.hashCode ^
      vorbelegterVorname.hashCode ^
      vorbelegterNachname.hashCode;
}

/// generated route for
/// [_i8.MandantenImportPage]
class MandantenImportRoute
    extends _i18.PageRouteInfo<MandantenImportRouteArgs> {
  MandantenImportRoute({
    _i19.Key? key,
    _i22.MandantenImportDatei? vorgabe,
    String herkunft = '',
    List<_i18.PageRouteInfo>? children,
  }) : super(
         MandantenImportRoute.name,
         args: MandantenImportRouteArgs(
           key: key,
           vorgabe: vorgabe,
           herkunft: herkunft,
         ),
         initialChildren: children,
       );

  static const String name = 'MandantenImportRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<MandantenImportRouteArgs>(
        orElse: () => const MandantenImportRouteArgs(),
      );
      return _i18.WrappedRoute(
        child: _i8.MandantenImportPage(
          key: args.key,
          vorgabe: args.vorgabe,
          herkunft: args.herkunft,
        ),
      );
    },
  );
}

class MandantenImportRouteArgs {
  const MandantenImportRouteArgs({this.key, this.vorgabe, this.herkunft = ''});

  final _i19.Key? key;

  final _i22.MandantenImportDatei? vorgabe;

  final String herkunft;

  @override
  String toString() {
    return 'MandantenImportRouteArgs{key: $key, vorgabe: $vorgabe, herkunft: $herkunft}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MandantenImportRouteArgs) return false;
    return key == other.key &&
        vorgabe == other.vorgabe &&
        herkunft == other.herkunft;
  }

  @override
  int get hashCode => key.hashCode ^ vorgabe.hashCode ^ herkunft.hashCode;
}

/// generated route for
/// [_i9.MandantenOverviewPage]
class MandantenOverviewRoute extends _i18.PageRouteInfo<void> {
  const MandantenOverviewRoute({List<_i18.PageRouteInfo>? children})
    : super(MandantenOverviewRoute.name, initialChildren: children);

  static const String name = 'MandantenOverviewRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i9.MandantenOverviewPage());
    },
  );
}

/// generated route for
/// [_i10.MandantenStackPage]
class MandantenStackRoute extends _i18.PageRouteInfo<void> {
  const MandantenStackRoute({List<_i18.PageRouteInfo>? children})
    : super(MandantenStackRoute.name, initialChildren: children);

  static const String name = 'MandantenStackRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return const _i10.MandantenStackPage();
    },
  );
}

/// generated route for
/// [_i11.NichtZugeordneteOrdnerPage]
class NichtZugeordneteOrdnerRoute extends _i18.PageRouteInfo<void> {
  const NichtZugeordneteOrdnerRoute({List<_i18.PageRouteInfo>? children})
    : super(NichtZugeordneteOrdnerRoute.name, initialChildren: children);

  static const String name = 'NichtZugeordneteOrdnerRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i11.NichtZugeordneteOrdnerPage());
    },
  );
}

/// generated route for
/// [_i12.RegisterImportPage]
class RegisterImportRoute extends _i18.PageRouteInfo<RegisterImportRouteArgs> {
  RegisterImportRoute({
    _i19.Key? key,
    int? vorgeschlagenerJahrgang,
    List<_i18.PageRouteInfo>? children,
  }) : super(
         RegisterImportRoute.name,
         args: RegisterImportRouteArgs(
           key: key,
           vorgeschlagenerJahrgang: vorgeschlagenerJahrgang,
         ),
         initialChildren: children,
       );

  static const String name = 'RegisterImportRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<RegisterImportRouteArgs>(
        orElse: () => const RegisterImportRouteArgs(),
      );
      return _i18.WrappedRoute(
        child: _i12.RegisterImportPage(
          key: args.key,
          vorgeschlagenerJahrgang: args.vorgeschlagenerJahrgang,
        ),
      );
    },
  );
}

class RegisterImportRouteArgs {
  const RegisterImportRouteArgs({this.key, this.vorgeschlagenerJahrgang});

  final _i19.Key? key;

  final int? vorgeschlagenerJahrgang;

  @override
  String toString() {
    return 'RegisterImportRouteArgs{key: $key, vorgeschlagenerJahrgang: $vorgeschlagenerJahrgang}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RegisterImportRouteArgs) return false;
    return key == other.key &&
        vorgeschlagenerJahrgang == other.vorgeschlagenerJahrgang;
  }

  @override
  int get hashCode => key.hashCode ^ vorgeschlagenerJahrgang.hashCode;
}

/// generated route for
/// [_i13.RegisterPage]
class RegisterRoute extends _i18.PageRouteInfo<void> {
  const RegisterRoute({List<_i18.PageRouteInfo>? children})
    : super(RegisterRoute.name, initialChildren: children);

  static const String name = 'RegisterRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return const _i13.RegisterPage();
    },
  );
}

/// generated route for
/// [_i14.SettingsPage]
class SettingsRoute extends _i18.PageRouteInfo<void> {
  const SettingsRoute({List<_i18.PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i14.SettingsPage());
    },
  );
}

/// generated route for
/// [_i15.VorgaengeVerwaltenPage]
class VorgaengeVerwaltenRoute extends _i18.PageRouteInfo<void> {
  const VorgaengeVerwaltenRoute({List<_i18.PageRouteInfo>? children})
    : super(VorgaengeVerwaltenRoute.name, initialChildren: children);

  static const String name = 'VorgaengeVerwaltenRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return const _i15.VorgaengeVerwaltenPage();
    },
  );
}

/// generated route for
/// [_i16.VorgangStartenPage]
class VorgangStartenRoute extends _i18.PageRouteInfo<void> {
  const VorgangStartenRoute({List<_i18.PageRouteInfo>? children})
    : super(VorgangStartenRoute.name, initialChildren: children);

  static const String name = 'VorgangStartenRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i16.VorgangStartenPage());
    },
  );
}

/// generated route for
/// [_i17.WordAutomationPage]
class WordAutomationRoute extends _i18.PageRouteInfo<void> {
  const WordAutomationRoute({List<_i18.PageRouteInfo>? children})
    : super(WordAutomationRoute.name, initialChildren: children);

  static const String name = 'WordAutomationRoute';

  static _i18.PageInfo page = _i18.PageInfo(
    name,
    builder: (data) {
      return _i18.WrappedRoute(child: const _i17.WordAutomationPage());
    },
  );
}
