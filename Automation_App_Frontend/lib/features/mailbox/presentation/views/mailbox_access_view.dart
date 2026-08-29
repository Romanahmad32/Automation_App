import 'package:automation_app/core/general_widgets/form/form_section.dart';
import 'package:automation_app/core/general_widgets/form/speichern_button.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_config.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_config_bloc/mailbox_config_bloc.dart';
import 'package:automation_app/features/mailbox/presentation/utils/mailbox_zugang_felder.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_auth_method_selector.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_enabled_switch.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_filter_section.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_imap_credentials_section.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_imap_server_section.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_microsoft_signin_section.dart';
import 'package:automation_app/features/settings/presentation/widgets/mail_signatur_sektion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Einstellungsmaske für den Postfach-Zugang (REQUIREMENTS.md §4.3/§7.1). Mit
/// diesen Angaben überwacht das Backend das Postfach ereignisbasiert und erfasst
/// eingehende Zentralruf-Antworten selbsttätig. Zwei Wege, und es entscheidet
/// allein, wo das Postfach liegt: IMAP mit Passwort (1&1/IONOS, Gmail) oder
/// Outlook/Microsoft per Browser-Anmeldung (OAuth — Microsoft erlaubt für IMAP
/// kein Passwort mehr). Über denselben Zugang wird auch versendet (§4.7).
///
/// Weil hier alles zur E-Mail steht, hängt unten auch die Signatur des
/// Direktversands (§4.7) — sie gehört fachlich zum Postausgang, nicht zu den
/// Kanzleistammdaten.
///
/// **Ein Speichern-Knopf für die ganze Seite.** Die Signatur hatte einen
/// eigenen, weil sie in einem anderen Einstellungssatz landet — eine
/// Begründung aus der Bauart, die auf dem Schirm nichts erklärte: Zwei Knöpfe
/// „Speichern" untereinander sahen aus wie zwei Formulare, und der obere stand
/// mitten auf der Seite, als gälte er für alles. Dass es zwei Wege ins Backend
/// sind, geht niemanden etwas an, der hier tippt.
///
/// Die Signatur geht dabei **auch dann** hinaus, wenn der Zugang unvollständig
/// ist: Sie hing nie an ihm, und ein halb ausgefülltes Postfachformular darf
/// sie nicht als Geisel nehmen. Dann wird gesagt, was gespeichert wurde und was
/// nicht.
class MailboxAccessView extends StatefulWidget {
  const MailboxAccessView({super.key});

  @override
  State<MailboxAccessView> createState() => _MailboxAccessViewState();
}

class _MailboxAccessViewState extends State<MailboxAccessView>
    with AutomaticKeepAliveClientMixin {
  bool _initialized = false;

  // Liegt im selben TabBarView wie die Kanzleidaten. KeepAlive verhindert, dass
  // die TabBarView den State beim Tab-Wechsel verwirft und das Formular leer
  // neu aufbaut (der Listener würde sonst nicht erneut befüllen).
  @override
  bool get wantKeepAlive => true;

  /// Ob bereits ein App-Passwort gespeichert ist — dann darf das Feld leer
  /// bleiben (unverändert), und wir schicken kein null-überschreibendes Passwort.
  bool _appPasswordSet = false;

  /// Zuletzt geladene Konfiguration (für die Microsoft-Konto-Anzeige).
  MailboxConfig _config = MailboxConfig.empty;

  final ScrollController _scrollController = ScrollController();

  /// Die Signatur gehört der Seite, nicht ihrem Abschnitt: Der eine
  /// Speichern-Knopf unten liest daraus.
  final TextEditingController _signatur = TextEditingController();

  final FormGroup _form = FormGroup({
    'enabled': FormControl<bool>(value: false),
    'authMethod': FormControl<MailboxAuthMethod>(
      value: MailboxAuthMethod.appPassword,
    ),
    'host': FormControl<String>(
      value: 'imap.ionos.de',
      validators: [Validators.required],
    ),
    'port': FormControl<String>(
      value: '993',
      validators: [Validators.required, Validators.number()],
    ),
    'useSsl': FormControl<bool>(value: true),
    'username': FormControl<String>(validators: [Validators.email]),
    'appPassword': FormControl<String>(),
    'folder': FormControl<String>(
      value: 'INBOX',
      validators: [Validators.required],
    ),
    'subjectFilter': FormControl<String>(value: 'Zentralruf'),
  });

  @override
  void dispose() {
    _scrollController.dispose();
    _signatur.dispose();
    super.dispose();
  }

  void _patch(MailboxConfig config) {
    _config = config;
    _appPasswordSet = config.appPasswordSet;
    MailboxZugangFelder.fuelle(_form, config);
  }

  /// Speichert beides: die Signatur immer (wenn geändert), den Zugang nur
  /// vollständig. Ein unvollständiger Zugang meldet sich, statt still nichts
  /// zu tun — die Feldfehler werden dabei sichtbar gemacht.
  ///
  /// Über die Signatur steht hier nichts: Sie geht in einen anderen
  /// Einstellungssatz, ihr Erfolg kommt entsprechend später — [MailSignaturSektion]
  /// meldet ihn selbst, wenn er da ist.
  void _save() {
    MailSignaturSektion.speichereWennGeaendert(context, _signatur.text);

    if (!_form.valid) {
      _form.markAllAsTouched();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Der Postfach-Zugang ist noch unvollständig — er wurde nicht '
            'gespeichert. Die rot markierten Felder fehlen.',
          ),
        ),
      );
      return;
    }

    _speichereZugang();
  }

  void _speichereZugang() {
    context.read<MailboxConfigBloc>().add(
      SaveMailboxConfigEvent(
        MailboxZugangFelder.alsAenderung(
          _form,
          stand: _config,
          appPasswortGesetzt: _appPasswordSet,
        ),
      ),
    );
  }

  void _onLoaded(BuildContext context, MailboxConfigLoaded state) {
    if (!_initialized || state.justSignedIn) {
      // Nach der Microsoft-Anmeldung hat das Backend Konto und Server
      // übernommen — die Maske muss die neuen Werte zeigen.
      _patch(state.config);
      setState(() => _initialized = true);
    } else {
      _config = state.config;
      _appPasswordSet = state.config.appPasswordSet;
    }

    final message = state.justSignedIn
        ? 'Microsoft-Anmeldung erfolgreich — das Postfach '
              '${state.config.microsoftAccount ?? ''} wird verwendet.'
        : state.justSaved
        ? 'Postfach-Zugang gespeichert. Die Überwachung verbindet sich '
              'mit den neuen Werten neu.'
        : null;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin
    return BlocConsumer<MailboxConfigBloc, MailboxConfigState>(
      listener: (context, state) {
        if (state is MailboxConfigLoaded) {
          _onLoaded(context, state);
        } else if (state is MailboxConfigError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        if (!_initialized && state is MailboxConfigLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final isSaving = state is MailboxConfigLoading;
        final signInPending = state is MailboxMicrosoftSignInPending;

        return Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ReactiveForm(
                    formGroup: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        const FormSection(
                          icon: Icons.mark_email_unread,
                          title: 'Postfach-Überwachung',
                          subtitle:
                              'Ist ein Zugang hinterlegt und die Überwachung '
                              'eingeschaltet, erfasst die App eingehende '
                              'Zentralruf-Antworten automatisch (erkannt über den '
                              'Betreff). Ohne Zugang bleibt sie inaktiv.',
                          children: [
                            MailboxEnabledSwitch(),
                            MailboxAuthMethodSelector(),
                          ],
                        ),
                        ReactiveValueListenableBuilder<MailboxAuthMethod>(
                          formControlName: 'authMethod',
                          builder: (context, control, _) {
                            final microsoft =
                                control.value ==
                                MailboxAuthMethod.microsoftOAuth;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 16,
                              children: microsoft
                                  ? [
                                      MailboxMicrosoftSignInSection(
                                        config: _config,
                                        signInPending: signInPending,
                                      ),
                                    ]
                                  : [
                                      MailboxImapCredentialsSection(
                                        appPasswordSet: _appPasswordSet,
                                      ),
                                      const MailboxImapServerSection(),
                                    ],
                            );
                          },
                        ),
                        const MailboxFilterSection(),
                        MailSignaturSektion(controller: _signatur),
                        SpeichernButton(
                          speichert: isSaving,
                          onSpeichern: signInPending ? null : _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
