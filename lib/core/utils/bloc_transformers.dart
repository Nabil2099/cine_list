import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// Cancels any active event handler when a newer event of the same group arrives.
EventTransformer<E> restartable<E>() {
  return (events, mapper) {
    late StreamController<E> controller;
    StreamSubscription<E>? upstreamSub;
    StreamSubscription<E>? innerSub;
    var upstreamDone = false;

    void tryClose() {
      if (upstreamDone && innerSub == null && !controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<E>(
      onListen: () {
        upstreamSub = events.listen(
          (event) {
            innerSub?.cancel();
            innerSub = mapper(event).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                innerSub = null;
                tryClose();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            upstreamDone = true;
            tryClose();
          },
        );
      },
      onCancel: () async {
        await innerSub?.cancel();
        innerSub = null;
        await upstreamSub?.cancel();
      },
    );

    return controller.stream;
  };
}

/// Drops incoming events while an earlier handler of the same group is running.
EventTransformer<E> droppable<E>() {
  return (events, mapper) {
    late StreamController<E> controller;
    StreamSubscription<E>? upstreamSub;
    StreamSubscription<E>? innerSub;
    var upstreamDone = false;

    void tryClose() {
      if (upstreamDone && innerSub == null && !controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<E>(
      onListen: () {
        upstreamSub = events.listen(
          (event) {
            if (innerSub != null) return;
            innerSub = mapper(event).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                innerSub = null;
                tryClose();
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            upstreamDone = true;
            tryClose();
          },
        );
      },
      onCancel: () async {
        await innerSub?.cancel();
        innerSub = null;
        await upstreamSub?.cancel();
      },
    );

    return controller.stream;
  };
}

/// Debounces burst events by [duration] and cancels prior handlers on newer input.
EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) {
    late StreamController<E> controller;
    StreamSubscription<E>? upstreamSub;
    StreamSubscription<E>? innerSub;
    Timer? debounceTimer;
    var upstreamDone = false;

    void tryClose() {
      if (upstreamDone &&
          debounceTimer == null &&
          innerSub == null &&
          !controller.isClosed) {
        controller.close();
      }
    }

    controller = StreamController<E>(
      onListen: () {
        upstreamSub = events.listen(
          (event) {
            debounceTimer?.cancel();
            innerSub?.cancel();
            innerSub = null;
            debounceTimer = Timer(duration, () {
              debounceTimer = null;
              innerSub = mapper(event).listen(
                controller.add,
                onError: controller.addError,
                onDone: () {
                  innerSub = null;
                  tryClose();
                },
              );
            });
          },
          onError: controller.addError,
          onDone: () {
            upstreamDone = true;
            tryClose();
          },
        );
      },
      onCancel: () async {
        debounceTimer?.cancel();
        debounceTimer = null;
        await innerSub?.cancel();
        innerSub = null;
        await upstreamSub?.cancel();
      },
    );

    return controller.stream;
  };
}

