import 'package:flutter_riverpod/flutter_riverpod.dart';

class SimpleNotifier<T> extends Notifier<T> {
  SimpleNotifier(this._initialState);

  final T _initialState;

  @override
  T build() => _initialState;

  @override
  set state(T value) => super.state = value;
  @override
  T get state => super.state;
}

NotifierProvider<SimpleNotifier<T>, T> simpleStateProvider<T>(T initialState) {
  return NotifierProvider<SimpleNotifier<T>, T>(
    () => SimpleNotifier<T>(initialState),
  );
}
