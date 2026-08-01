import 'package:automation_app/core/general_classes/failures/failure.dart';

sealed class Either<L, R> {}

class Left<L, R> extends Either<L, R> {
  final L value;

  Left(this.value);
}

class Right<L, R> extends Either<L, R> {
  final R value;

  Right(this.value);
}

abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

class NoParams {
  const NoParams();
}
