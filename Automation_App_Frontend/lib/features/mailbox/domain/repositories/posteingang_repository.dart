import 'package:automation_app/features/mailbox/domain/entities/posteingang.dart';

abstract class PosteingangRepository {
  Future<PosteingangSeite> ladeSeite({String? cursor});
  Future<PosteingangInhalt> ladeInhalt(String id);
  void abbrechen();
}

class PosteingangFehler implements Exception {
  final String meldung;
  const PosteingangFehler(this.meldung);
}
