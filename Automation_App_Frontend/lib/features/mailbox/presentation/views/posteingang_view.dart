import 'dart:async';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_detail.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_liste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/mailbox_versand_leiste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosteingangView extends StatefulWidget {
  const PosteingangView({super.key});
  @override
  State<PosteingangView> createState() => _PosteingangViewState();
}

class _PosteingangViewState extends State<PosteingangView> {
  Timer? _rueckfall;
  @override
  void initState() {
    super.initState();
    // Auch ohne eingeschalteten Monitor oder SignalR werden neue Mails sichtbar.
    // Nur die erste sichtbare Seite ohne geöffneten Text wird nachgeladen.
    _rueckfall = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final cubit = context.read<PosteingangCubit>();
      if (!cubit.state.laedt &&
          cubit.state.seitennummer == 1 &&
          cubit.state.auswahl == null) {
        cubit.aktualisieren();
      }
    });
  }

  @override
  void dispose() {
    _rueckfall?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PosteingangCubit, PosteingangState>(
        builder: (context, state) => Column(
          children: [
            const MailboxVersandLeiste(),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final breit = constraints.maxWidth >= 800;
                  return Flex(
                    direction: breit ? Axis.horizontal : Axis.vertical,
                    children: [
                      Expanded(
                        flex: breit ? 2 : 1,
                        child: PosteingangListe(state: state),
                      ),
                      if (breit)
                        const VerticalDivider(width: 1)
                      else
                        const Divider(height: 1),
                      Expanded(
                        flex: breit ? 3 : 1,
                        child: PosteingangDetail(state: state),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
}
