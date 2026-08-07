import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/dashboard/domain/services/dashboard_uebersicht.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_offene_vorgaenge_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_postfach_karte.dart';
import 'package:automation_app/features/dashboard/presentation/widgets/dashboard_register_karte.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/mailbox_inbox_cubit/mailbox_inbox_cubit.dart';
import 'package:automation_app/features/vorgaenge/domain/entities/vorgang.dart';
import 'package:automation_app/features/vorgaenge/presentation/blocs/vorgang_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Inhalt der Startseite: offene Vorgänge und unbearbeitete Postfach-Antworten
/// nebeneinander, darunter der Registerausschnitt über die volle Breite. Auf
/// schmalen Fenstern stehen die drei Karten untereinander.
///
/// Die Daten kommen aus den bestehenden app-weiten Beständen — dem
/// [VorgangCubit] (Singleton) und dem [MailboxInboxCubit] der Seite, der über
/// SignalR live nachlädt. Die Startseite hält keinen eigenen Zustand.
class DashboardView extends StatelessWidget {
  /// Ab dieser Fensterbreite stehen Vorgänge und Postfach nebeneinander.
  static const double zweiSpaltenAb = 1000;

  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VorgangCubit, List<Vorgang>>(
      bloc: getIt<VorgangCubit>(),
      builder: (context, vorgaenge) {
        final uebersicht = DashboardUebersicht.aus(vorgaenge);

        return BlocBuilder<MailboxInboxCubit, MailboxInboxState>(
          builder: (context, postfach) {
            final vorgaengeKarte = DashboardOffeneVorgaengeKarte(
              uebersicht: uebersicht,
            );
            final postfachKarte = DashboardPostfachKarte(
              antworten: postfach.replies,
              status: postfach.status,
              fehler: postfach.error,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final zweispaltig = constraints.maxWidth >= zweiSpaltenAb;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (zweispaltig)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: vorgaengeKarte),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: postfachKarte),
                          ],
                        )
                      else ...[
                        vorgaengeKarte,
                        const SizedBox(height: 16),
                        postfachKarte,
                      ],
                      const SizedBox(height: 16),
                      DashboardRegisterKarte(uebersicht: uebersicht),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
