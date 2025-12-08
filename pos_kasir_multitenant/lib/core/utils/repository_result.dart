/// Result pattern untuk repository operations
/// Menghindari exception throwing dan memberikan error handling yang lebih baik
class RepositoryResult<T> {
  final T? data;
  final String? error;
  final bool success;

  RepositoryResult._({
    this.data,
    this.error,
    required this.success,
  });

  factory RepositoryResult.success(T data) {
    return RepositoryResult._(
      data: data,
      success: true,
    );
  }

  factory RepositoryResult.failure(String error) {
    return RepositoryResult._(
      error: error,
      success: false,
    );
  }

  /// Execute action if successful
  RepositoryResult<R> map<R>(R Function(T data) transform) {
    if (success && data != null) {
      try {
        return RepositoryResult.success(transform(data as T));
      } catch (e) {
        return RepositoryResult.failure(e.toString());
      }
    }
    return RepositoryResult.failure(error ?? 'Unknown error');
  }

  /// Execute action if failed
  RepositoryResult<T> onError(void Function(String error) action) {
    if (!success && error != null) {
      action(error!);
    }
    return this;
  }
}
