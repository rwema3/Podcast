import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final config = {
    'apiKey': Platform.environment['API_KEY'],
