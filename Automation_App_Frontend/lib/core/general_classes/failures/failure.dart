abstract class Failure {
  final String message;

  Failure({required this.message});
}

class ServerFailure extends Failure {
  ServerFailure({required super.message});
}

class LocalFailure extends Failure {
  LocalFailure({required super.message});
}
