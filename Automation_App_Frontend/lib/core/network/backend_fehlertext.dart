import 'dart:convert';

import 'package:dio/dio.dart';

/// Liest den anzeigbaren, deutschen Fehlertext aus einer [DioException] —
/// unabhängig davon, in welcher Form der Dienst geantwortet hat.
///
/// Das Backend antwortet auf Fehler einheitlich mit RFC-7807-ProblemDetails
/// (`detail`/`title`), einzelne Endpunkte melden ihren Fehlerstatus aber
/// weiterhin eingebettet in eine Erfolgs-Antwort (`message`, z. B.
/// WordAutomation, Zentralruf) oder als nackten String/Byte-Strom. Diese eine
/// Stelle kennt alle vier Formen, damit keine Datasource sie mehr einzeln
/// nachbauen muss.
///
/// Gibt `null` zurück, wenn der Dienst gar nicht geantwortet hat (Timeout,
/// keine Verbindung) — der Aufrufer kennt dafür meist eine passendere,
/// eigene Meldung ("Läuft der Dienst noch?") als ein Statuscode es könnte.
String? backendFehlertext(DioException exception) {
  String? nichtLeererText(Object? wert) {
    if (wert is! String) return null;
    final getrimmt = wert.trim();
    return getrimmt.isEmpty ? null : getrimmt;
  }

  final response = exception.response;
  if (response == null) {
    return null;
  }

  final data = response.data;
  if (data is Map) {
    final detail = nichtLeererText(data['detail']);
    if (detail != null) return detail;
    final title = nichtLeererText(data['title']);
    if (title != null) return title;
    final message = nichtLeererText(data['message']);
    if (message != null) return message;
  }

  final stringBody = nichtLeererText(data);
  if (stringBody != null) return stringBody;

  if (data is List<int> && data.isNotEmpty) {
    final bytesText = nichtLeererText(utf8.decode(data, allowMalformed: true));
    if (bytesText != null) return bytesText;
  }

  final statusCode = response.statusCode;
  return statusCode == null
      ? 'Der Dienst hat ohne Statuscode geantwortet.'
      : 'Der Dienst hat mit Status $statusCode geantwortet.';
}
