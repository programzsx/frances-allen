import 'package:flutter/material.dart';
import 'theme/desktop_theme.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const DesktopApp());
}

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '知识问答',
      debugShowCheckedModeBanner: false,
      theme: DesktopTheme.lightTheme,
      home: const HomePage(),
    );
  }
}
