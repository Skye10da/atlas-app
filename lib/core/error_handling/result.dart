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

  String? get technicalDetails {
    final buf = StringBuffer(error.message);
    if (error.cause != null) {
      buf.write('\nCause: ${error.cause}');
    }
    if (stackTrace != null) {
      buf.write('\n$stackTrace');
    }
    return buf.toString();
  }
}

abstract class AppException implements Exception {
  const AppException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  String get code;
  String get userMessage;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, [super.cause]);
  @override
  String get code => 'DATABASE_ERROR';
  @override
  String get userMessage => 'Something went wrong while loading your data.';
}

class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
  @override
  String get code => 'NETWORK_ERROR';
  @override
  String get userMessage => 'Unable to connect. Please check your connection and try again.';
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.cause]);
  @override
  String get code => 'NOT_FOUND';
  @override
  String get userMessage => 'The requested item could not be found.';
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);
  @override
  String get code => 'VALIDATION_ERROR';
  @override
  String get userMessage => 'There was a problem with the data. Please try again.';
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, [super.cause]);
  @override
  String get code => 'UNAUTHORIZED';
  @override
  String get userMessage => 'Please sign in to access this feature.';
}

class DuplicateBookException extends AppException {
  const DuplicateBookException(super.message, [super.cause]);
  @override
  String get code => 'DUPLICATE_BOOK';
  @override
  String get userMessage => 'This book already exists in your library.';
}
