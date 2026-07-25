import 'dart:async';

// Writes land in one screen but are usually visible in several. Repositories
// announce what changed here and any list already built elsewhere reloads,
// instead of showing stale data until the user pulls to refresh.
enum DataTopic { posts, deals, profile, wallet }

class DataBus {
  DataBus._();

  static final _ctrl = StreamController<DataTopic>.broadcast();

  static Stream<DataTopic> on(Set<DataTopic> topics) =>
      _ctrl.stream.where(topics.contains);

  static void changed(DataTopic topic) {
    if (!_ctrl.isClosed) _ctrl.add(topic);
  }
}
