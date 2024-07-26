import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mqtt/view/home_view.dart';
import 'package:mqtt/view/home_view5.dart';
import 'package:mqtt/view/landing_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LandingView(),
      //MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}