import 'package:flutter/material.dart';

Future<T?> push<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

Future<T?> replace<T>(BuildContext context, Widget page) =>
    Navigator.of(context).pushReplacement<T, void>(MaterialPageRoute<T>(builder: (_) => page));

/// Opens [page] and clears the back stack (no return to Splash / auth screens).
Future<void> replaceAll(BuildContext context, Widget page) =>
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => page),
      (_) => false,
    );
