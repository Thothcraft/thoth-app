import 'package:flutter/material.dart';

/// Wraps a page that was authored without its own Scaffold so it renders
/// correctly as a pushed full-screen route (title bar + back button).
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
    );
  }
}
