import 'package:flutter/material.dart';

/// The pop result arrives before the reverse transition finishes. Wait for
/// the route's overlay entries to be removed before reusing modal resources.
Future<T?> showSettledDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  try {
    return await navigator.push(route);
  } finally {
    await route.completed;
  }
}

Future<T?> showSettledSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = false,
}) async {
  TransitionRoute<dynamic>? route;
  final result = await showModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor,
    isScrollControlled: isScrollControlled,
    builder: (ctx) {
      route = ModalRoute.of(ctx);
      return builder(ctx);
    },
  );
  await route?.completed;
  return result;
}
