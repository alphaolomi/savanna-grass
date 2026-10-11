/// One piece of server data as a screen sees it: what we have, whether a
/// fetch is running, and why the last one failed.
///
/// The three are independent on purpose. A refresh that fails keeps the data
/// it had (an offline phone still shows yesterday's numbers), and a refresh
/// in flight keeps showing the old data rather than a spinner.
class Loadable<T> {
  const Loadable({this.data, this.loading = false, this.error, this.loadedAt});

  final T? data;
  final bool loading;
  final String? error;
  final DateTime? loadedAt;

  bool get hasData => data != null;

  Loadable<T> started() => Loadable(data: data, loading: true, loadedAt: loadedAt);

  Loadable<T> succeeded(T value, DateTime at) => Loadable(data: value, loadedAt: at);

  Loadable<T> failed(String message) => Loadable(data: data, error: message, loadedAt: loadedAt);

  /// True when [loadedAt] is missing or older than [maxAge] at [now].
  bool isStale(DateTime now, Duration maxAge) {
    final at = loadedAt;
    return at == null || now.difference(at) >= maxAge;
  }
}
