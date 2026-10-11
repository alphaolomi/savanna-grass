import 'package:flutter/material.dart';

import '../app_state.dart';

/// A page pushed on top of home that lives only while the session does.
///
/// It rebuilds with [state], and if the session ends while it is open —
/// signed out on the Profile page, or a 401 during a background refresh — it
/// pops back to the root so it never sits over the login screen.
class SignedInPage extends StatefulWidget {
  const SignedInPage({super.key, required this.state, required this.builder});

  final AppState state;
  final WidgetBuilder builder;

  @override
  State<SignedInPage> createState() => _SignedInPageState();
}

class _SignedInPageState extends State<SignedInPage> {
  bool _leaving = false;

  void _leaveIfSignedOut() {
    if (_leaving || widget.state.auth == AuthStatus.signedIn) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) {
      _leaveIfSignedOut();
      return widget.builder(context);
    },
  );
}
