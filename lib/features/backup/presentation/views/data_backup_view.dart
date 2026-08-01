import 'package:automation_app/core/di/injection.dart';
import 'package:automation_app/features/backup/presentation/cubit/backup_cubit.dart';
import 'package:automation_app/features/backup/presentation/widgets/data_backup_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tab „Datensicherung" in den Einstellungen: stellt dem Inhalt den
/// [BackupCubit] bereit.
class DataBackupView extends StatelessWidget {
  const DataBackupView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<BackupCubit>(),
      child: const DataBackupBody(),
    );
  }
}
