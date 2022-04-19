import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ubber/telas/Home.dart';
import 'package:ubber/Rotas.dart';
import 'package:firebase_core/firebase_core.dart';

final ThemeData temaPadrao = ThemeData(
    primaryColor: Color(0xff37474f), colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Color(0xff546e7a))
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
   runApp(MaterialApp(
    title: "Uber",
    home: Home(),
     theme: ThemeData(
         primaryColor: Color(0xff37474f), colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Color(0xff546e7a))
     ),
    initialRoute: "/",
    onGenerateRoute: Rotas.gerarRotas,
    debugShowCheckedModeBanner: false,
  ));
}