/// A persisted (restorable) browser tab.
class WebTabState {
  const WebTabState({
    required this.id,
    this.url,
    this.title,
    required this.order,
    required this.lastActiveAt,
  });

  final String id;
  final String? url;
  final String? title;
  final int order;
  final DateTime lastActiveAt;
}