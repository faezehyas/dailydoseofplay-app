import 'package:flutter/material.dart';

import 'shell.dart';

void main() => runApp(const DailyDoseOfPlay());

class DailyDoseOfPlay extends StatelessWidget {
  const DailyDoseOfPlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Daily Dose of Play',
      debugShowCheckedModeBanner: false,
      home: Shell(),
    );
  }
}
