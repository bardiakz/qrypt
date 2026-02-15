import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleNotifier<T> extends Notifier<T> {
  SimpleNotifier(this._initialState);

  final T _initialState;

  @override
  T build() => _initialState;
}

NotifierProvider<SimpleNotifier<T>, T> simpleStateProvider<T>(T initialState) {
  return NotifierProvider<SimpleNotifier<T>, T>(
    () => SimpleNotifier<T>(initialState),
  );
}
