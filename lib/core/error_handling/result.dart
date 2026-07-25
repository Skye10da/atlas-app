sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error, [this.stackTrace]);
  final AppException error;
  final StackTrace? stackTrace;
}

abstract class AppException implements Exception {
  const AppException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  String get code;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
  @override
  String get code => 'DATABASE_ERROR';
}

class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
  @override
  String get code => 'NETWORK_ERROR';
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.cause]);
  @override
  String get code => 'NOT_FOUND';
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);
  @override
  String get code => 'VALIDATION_ERROR';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, [super.cause]);
  @override
  String get code => 'UNAUTHORIZED';
}
