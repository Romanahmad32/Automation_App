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
/// keine Verbindung). Der Aufrufer weiß dann, *welche* Aufgabe deshalb liegen
/// blieb — den Grund dafür kennt er nicht; den setzt [dienstOhneAntwort]
/// daneben.
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

/// Der Satz für den Fall, dass [backendFehlertext] `null` liefert: Es kam
/// **keine** Antwort an.
///
/// Bis hierher stand an den Aufrufstellen ein Text über die Aufgabe — „Beim
/// bearbeiten des Word-Dokuments ist ein Fehler aufgetreten". Der schickt den
/// Anwalt ins Dokument, während in Wahrheit der Dienst steht: Er sucht an der
/// einen Stelle, an der nichts zu finden ist. [was] nennt weiterhin die
/// Aufgabe, der Grund kommt aus dem Typ der [DioException] — und mit ihm der
/// einzige Hinweis, der hier weiterhilft.
///
/// Die Unterscheidung ist nicht kosmetisch: Bei einer Zeitüberschreitung läuft
/// der Dienst und war nur zu langsam (die PDF-Wandlung darf kalt mehrere
/// Sekunden brauchen) — ein zweiter Versuch hat Aussicht. Ist die Verbindung
/// weg, ist der Kindprozess gestorben, und Wiederholen hilft nie.
String dienstOhneAntwort(DioException exception, String was) {
  final grund = switch (exception.type) {
    DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout =>
      'Der Dienst hat zu lange gebraucht. Bitte versuchen Sie es noch einmal.',
    DioExceptionType.cancel => 'Der Vorgang wurde abgebrochen.',
    // connectionError, connectionTimeout, badCertificate, unknown: In allen
    // vier Fällen ist der Dienst nicht ansprechbar. Ein Neustart der Anwendung
    // startet ihn mit (AppBootstrap) — für den Anwalt ist er sonst unsichtbar,
    // ein Hinweis auf „den Dienst" allein wäre also kein Handgriff.
    _ =>
      'Der Dienst der Anwendung antwortet nicht. '
          'Bitte starten Sie die Anwendung neu.',
  };

  return '$was. $grund';
}
