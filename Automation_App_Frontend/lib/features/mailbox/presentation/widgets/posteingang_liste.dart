import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_cubit.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_filter.dart';
import 'package:automation_app/features/mailbox/presentation/blocs/posteingang_state.dart';
import 'package:automation_app/features/mailbox/presentation/utils/posteingang_tagesgruppen.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_filter_leiste.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_gruppen_kopf.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_listen_fuss.dart';
import 'package:automation_app/features/mailbox/presentation/widgets/posteingang_zeile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Die Posteingangsliste: Filterleiste, nach Tagen gruppierte Zeilen, Fußzeile
/// — der Umbau zu Issue #134. Nimmt ihre Daten als Konstruktorparameter
/// entgegen (`state`) und holt den Cubit nur für Handlungen aus dem Kontext,
/// damit sie ohne DI testbar bleibt.
class PosteingangListe extends StatelessWidget {
  final PosteingangState state;
  const PosteingangListe({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PosteingangCubit>();
    final sichtbar = state.sichtbar;
    return Column(
      children: [
        PosteingangFilterLeiste(
          filter: state.filter,
          zentralrufAnzahl: state.zentralrufAnzahl,
          onChanged: cubit.setzeFilter,
        ),
        if (state.laedt && state.eintraege.isEmpty)
          const LinearProgressIndicator(),
        if (state.fehler != null) _fehlerZeile(context),
        if (state.neueNachrichten) _neueNachrichtenZeile(cubit),
        Expanded(child: _liste(context, cubit, sichtbar)),
        PosteingangListenFuss(
          geladen: state.eintraege.length,
          gesamt: state.seite?.gesamt ?? 0,
          alleGeladen: state.alleGeladen,
          laedt: state.laedt,
          onMehr: cubit.aeltere,
        ),
      ],
    );
  }

  Widget _fehlerZeile(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      state.fehler!,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _neueNachrichtenZeile(PosteingangCubit cubit) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: TextButton(
      onPressed: cubit.aktualisieren,
      child: const Text('Neue Nachrichten laden'),
    ),
  );

  Widget _liste(
    BuildContext context,
    PosteingangCubit cubit,
    List<PosteingangEintrag> sichtbar,
  ) {
    if (sichtbar.isEmpty) {
      return Center(
        child: Text(
          state.laedt
              ? 'Nachrichten werden geladen …'
              : state.filter == PosteingangFilter.alle
              ? 'Keine Nachrichten im Posteingang.'
              : 'Keine Nachrichten für diesen Filter.',
        ),
      );
    }
    final gruppen = gruppierePosteingangNachTag(sichtbar);
    final items = <Object>[
      for (final gruppe in gruppen) ...[gruppe.tag, ...gruppe.eintraege],
    ];
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => _item(cubit, items[index]),
    );
  }

  Widget _item(PosteingangCubit cubit, Object item) {
    if (item is DateTime) return PosteingangGruppenKopf(tag: item);
    final eintrag = item as PosteingangEintrag;
    return PosteingangZeile(
      eintrag: eintrag,
      ausgewaehlt: state.auswahl?.id == eintrag.id,
      onTap: () => cubit.oeffnen(eintrag),
      bezug: state.bezugFuer(eintrag.id),
      zentralruf: state.zentralrufFuer(eintrag.messageId),
    );
  }
}
