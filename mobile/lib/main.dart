import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'pages/home_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FrancesAllenApp());
}

class FrancesAllenApp extends StatelessWidget {
  const FrancesAllenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        return MaterialApp(
          title: '知识问答',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const HomePage(),
        );
      },
    );
  }
}
