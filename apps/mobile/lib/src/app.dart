import 'package:ficct_final_app/src/core/theme/app_theme.dart';
import 'package:ficct_final_app/src/features/home/presentation/home_page.dart';
import 'package:flutter/material.dart';

class FicctFinalApp extends StatelessWidget {
  const FicctFinalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FICCT Final App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomePage(),
    );
  }
}
