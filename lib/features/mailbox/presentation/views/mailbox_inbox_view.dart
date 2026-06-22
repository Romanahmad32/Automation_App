import 'package:auto_route/auto_route.dart';
import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/core/theme/presentation/soft_tone.dart';
import 'package:automation_app/features/mailbox/domain/entities/mailbox_status.dart';
import 'package:automation_app/features/mailbox/domain/entities/received_reply.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/domain/entities/zentralruf_reply_data.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/vorgangsdaten_cubit.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/blocs/zentralruf_reply_bloc.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/manual_reply_input.dart';
import 'package:automation_app/features/zentralruf_reply/presentation/widgets/vorgangsdaten_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Reihenfolge der Tabs siehe AppShellPage: nach dem Vereinen von Postfach und
/// manueller Antwort liegt Word Automation auf Index 2.
const int _wordAutomationTabIndex = 2;

/// Vereinte Ansicht „Zentralruf-Antworten": oben der Verbindungsstatus der
/// Überwachung, links die automatisch erfassten Treffer plus der Einstieg
/// „Manuell einfügen", rechts das gemeinsame, editierbare Vorgangsdaten-Formular
/// ([VorgangsdatenForm]) — egal ob die Antwort per Postfach kam oder von Hand
/// eingefügt wurde. „Übernehmen" füllt den Vorgang vor und wechselt zu Word.
class MailboxInboxView extends StatefulWidget {
  const MailboxInboxView({super.key});

  @override
  State<MailboxInboxView> createState() => _MailboxInboxViewState();
}

class _MailboxInboxViewState extends State<MailboxInboxView> {
  String? _selectedId;
  bool _manualMode = false;

  void _gemeinsamUebernehmen(ZentralrufReplyData daten) {
    // Antwort über die Referenz dem richtigen Vorgang zuordnen und ihn auf
    // „Beantwortet" schalten (Req. 3.3) — so bleiben mehrere offene Vorgänge
    // sauber unterscheidbar.
    getIt<VorgangCubit>().uebernehmeAntwort(daten);
    // Übergangsweise zusätzlich in den globalen „letzten" Blob, aus dem der
    // Word-Assistent noch vorbelegt; entfällt, sobald er aus dem Vorgang liest
    // (Phase 4).
    getIt<VorgangsdatenCubit>().uebernehmen(daten);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Vorgangsdaten übernommen. Passende Felder werden beim Ausfüllen der '
          'Vorlage automatisch vorbelegt.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
    AutoTabsRouter.of(context).setActiveIndex(_wordAutomationTabIndex);
  }

  void _treffferUebernehmen(ReceivedReply reply, ZentralrufReplyData daten) {
    // Mit der Übernahme gilt der erfasste Treffer als erledigt.
    context.read<MailboxInboxCubit>().acknowledge(reply.id);
    setState(() => _selectedId = null);
    _gemeinsamUebernehmen(daten);
  }

  void _manuellUebernehmen(ZentralrufReplyData daten) {
    setState(() => _manualMode = false);
    context.read<ZentralrufReplyBloc>().add(const ResetZentralrufReplyEvent());
    _gemeinsamUebernehmen(daten);
  }

  void _manuellOeffnen() {
    context.read<ZentralrufReplyBloc>().add(const ResetZentralrufReplyEvent());
    setState(() {
      _manualMode = true;
      _selectedId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MailboxInboxCubit, MailboxInboxState>(
      builder: (context, state) {
        final replies = state.replies;
        final selected = replies
            .where((reply) => reply.id == _selectedId)
            .firstOrNull;

        return Column(
          children: [
            _StatusBanner(status: state.status, error: state.error),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 360,
                    child: _ReplyList(
                      replies: replies,
                      selectedId: _selectedId,
                      manualSelected: _manualMode,
                      loading: state.loading && replies.isEmpty,
                      status: state.status,
                      onSelect: (id) => setState(() {
                        _selectedId = id;
                        _manualMode = false;
                      }),
                      onManual: _manuellOeffnen,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _DetailPane(
                      manualMode: _manualMode,
                      selected: selected,
                      onTrefferUebernehmen: _treffferUebernehmen,
                      onManuellUebernehmen: _manuellUebernehmen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Rechte Seite: manuelles Eingabepanel bzw. dessen Ergebnis, ein ausgewählter
/// Treffer oder ein Platzhalter.
class _DetailPane extends StatelessWidget {
  final bool manualMode;
  final ReceivedReply? selected;
  final void Function(ReceivedReply reply, ZentralrufReplyData daten)
  onTrefferUebernehmen;
  final void Function(ZentralrufReplyData daten) onManuellUebernehmen;

  const _DetailPane({
    required this.manualMode,
    required this.selected,
    required this.onTrefferUebernehmen,
    required this.onManuellUebernehmen,
  });

  @override
  Widget build(BuildContext context) {
    if (manualMode) {
      final state = context.watch<ZentralrufReplyBloc>().state;
      return switch (state) {
        ZentralrufReplyParsed(result: final result) => VorgangsdatenForm(
          key: ObjectKey(result),
          data: result.data,
          warnings: result.warnings,
          onUebernehmen: onManuellUebernehmen,
        ),
        ZentralrufReplyError(message: final message) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
        _ => const ManualReplyInput(),
      };
    }

    if (selected case final reply?) {
      final theme = Theme.of(context);
      return VorgangsdatenForm(
        key: ValueKey(reply.id),
        data: reply.data,
        warnings: reply.warnings,
        onUebernehmen: (daten) => onTrefferUebernehmen(reply, daten),
        kopf: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Erfasste Antwort', style: theme.textTheme.titleMedium),
            if (reply.subject case final subject?) ...[
              const SizedBox(height: 4),
              Text(subject, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        fuss: _OriginaltextPanel(rawText: reply.rawText),
      );
    }

    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Eine Antwort links auswählen oder „Manuell einfügen", um die '
          'erkannten Daten zu prüfen und zu übernehmen.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Aufklappbarer Originaltext der Mail: zum Nachlesen und zum Markieren/Kopieren
/// einzelner Angaben, falls das automatische Mapping etwas nicht erkannt hat.
class _OriginaltextPanel extends StatelessWidget {
  final String? rawText;

  const _OriginaltextPanel({required this.rawText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = rawText;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: ExpansionTile(
        leading: const Icon(Icons.article_outlined),
        title: const Text('Originaltext der Mail'),
        subtitle: Text(
          text == null
              ? 'Für diese Antwort nicht verfügbar.'
              : 'Zum Nachlesen und Kopieren aufklappen.',
          style: theme.textTheme.bodySmall,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: text == null
            ? const []
            : [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Alles kopieren'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Originaltext in die Zwischenablage kopiert.',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 320),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
      ),
    );
  }
}

/// Statuszeile: verbunden / inaktiv / Fehler, plus letzter Empfang.
class _StatusBanner extends StatelessWidget {
  final MailboxStatus status;
  final String? error;

  const _StatusBanner({required this.status, required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color accent, IconData icon, String text) = switch (status) {
      _ when error != null => (
        theme.colorScheme.error,
        Icons.error_outline,
        error!,
      ),
      MailboxStatus(connected: true) => (
        Colors.green,
        Icons.cloud_done,
        'Verbunden — eingehende Antworten werden automatisch erfasst'
            '${status.idleSupported ? ' (Push/IDLE)' : ' (Abruf-Modus)'}.',
      ),
      MailboxStatus(enabled: false) => (
        theme.colorScheme.outline,
        Icons.cloud_off,
        'Überwachung ausgeschaltet. In den Einstellungen unter '
            '"Postfach-Zugang" aktivieren.',
      ),
      MailboxStatus(configured: false) => (
        theme.colorScheme.tertiary,
        Icons.key_off,
        'Kein Postfach-Zugang hinterlegt. In den Einstellungen unter '
            '"Postfach-Zugang" einrichten.',
      ),
      _ when status.lastError != null => (
        theme.colorScheme.error,
        Icons.sync_problem,
        'Verbindung unterbrochen: ${status.lastError}. Es wird automatisch '
            'erneut verbunden.',
      ),
      _ => (
        theme.colorScheme.tertiary,
        Icons.sync,
        'Überwachung eingeschaltet — verbinde …',
      ),
    };

    final tone = SoftTone.fromAccent(accent, theme.colorScheme);
    return Container(
      width: double.infinity,
      color: tone.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: tone.foreground, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: tone.foreground)),
          ),
          if (status.lastReplyAt case final last?) ...[
            const SizedBox(width: 12),
            Text(
              'Letzter Empfang: ${_formatDateTime(last)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tone.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReplyList extends StatelessWidget {
  final List<ReceivedReply> replies;
  final String? selectedId;
  final bool manualSelected;
  final bool loading;
  final MailboxStatus status;
  final ValueChanged<String> onSelect;
  final VoidCallback onManual;

  const _ReplyList({
    required this.replies,
    required this.selectedId,
    required this.manualSelected,
    required this.loading,
    required this.status,
    required this.onSelect,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: manualSelected
              ? FilledButton.icon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manuell einfügen'),
                  onPressed: onManual,
                )
              : FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Manuell einfügen'),
                  onPressed: onManual,
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Text(
                'Erfasste Antworten',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : replies.isEmpty
              ? _EmptyHint(status: status)
              : ListView.separated(
                  itemCount: replies.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    final data = reply.data;
                    final hatWarnung =
                        reply.warnings.isNotEmpty ||
                        data.keinVersichererErmittelt;
                    return ListTile(
                      selected: reply.id == selectedId,
                      selectedTileColor: theme.colorScheme.primary.withValues(
                        alpha: 0.08,
                      ),
                      leading: Icon(
                        hatWarnung
                            ? Icons.warning_amber
                            : Icons.mark_email_unread,
                        color: hatWarnung ? theme.colorScheme.tertiary : null,
                      ),
                      title: Text(
                        data.referenz ??
                            data.versichererName ??
                            '(ohne Referenz)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${data.versichererName ?? 'Versicherer unbekannt'}'
                        ' · ${_formatDateTime(reply.receivedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelect(reply.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final MailboxStatus status;

  const _EmptyHint({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              status.connected
                  ? 'Noch keine offenen Antworten. Neue Zentralruf-Mails '
                        'erscheinen hier automatisch.'
                  : 'Sobald ein Postfach-Zugang hinterlegt und die Überwachung '
                        'aktiv ist, erscheinen eingehende Antworten hier.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} '
      '${two(value.hour)}:${two(value.minute)}';
}
