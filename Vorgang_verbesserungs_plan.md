1. Word-Formulardaten am Vorgang speichern (größter Einzelgewinn)

Die im Wizard ausgefüllten formData (inkl. manuell nachgetragener Felder wie Unfallort, Schadenspositionen) sind nach der Generierung weg. Erstellt der Anwalt ein zweites Schreiben zum selben Vorgang — oder korrigiert das erste — muss er alles neu eingeben. Vorschlag: beim Generieren die Feldwerte als feldWerte-Map am Vorgang persistieren und beim erneuten Öffnen als Prefill anbieten (mit Vorrang vor der Heuristik, da vom Anwalt bestätigt). Ebenso die Schadensaufstellung.

2. Rückfluss in den Vorgang und den Mandanten

- Trägt der Anwalt im Wizard einen Wert ein, der einem Vorgangsfeld entspricht (Unfallort, Polizei-Nr., Gegner-Kennzeichen), sollte der Vorgang aktualisiert werden — heute bleibt er auf dem Stand von „Vorgang starten".
- Der Mandant lernt nicht dazu: Ein in „Vorgang starten" eingetipptes Kennzeichen landet nur per explizitem Speichern-Button beim Mandanten. Besser: beim Speichern des Vorgangs erkennen „Kennzeichen HG-E 1427 ist bei Mandant Müller noch nicht hinterlegt" und mit einem Klick (oder automatisch, mit Hinweis) in mandant.kennzeichen übernehmen. Gleiches für geänderte Adresse/Telefon: Diff anzeigen, „Im Register aktualisieren?".

3. Wiedererkennung bei freier Eingabe (Duplikat-Schutz + Komfort)

Heute muss der Anwalt aktiv im Dropdown suchen. Intelligenter:
- Beim Tippen des Nachnamens fuzzy gegen das Mandantenregister matchen → Inline-Hinweis „Meinten Sie Max Müller, Hauptstr. 3? Übernehmen". Verhindert Duplikate und spart Tipparbeit.
- Umgekehrt: Ein eingegebenes Mandanten-Kennzeichen, das bereits bei einem Mandanten hinterlegt ist, schlägt diesen Mandanten vor.

4. Versicherer-Wissensbasis aufbauen

Jede Zentralruf-Antwort enthält Name/Anschrift/E-Mail/Telefon eines Versicherers — das wird heute nur am einzelnen Vorgang gespeichert. Ein eigenes Versicherer-Register (Backend-Tabelle, aus Antworten automatisch befüllt/aktualisiert) ermöglicht:
- Lücken füllen: meldet eine Antwort missingFields (z. B. keine E-Mail), die Daten aus früheren Antworten desselben Versicherers ergänzen — mit Herkunftshinweis.
- Bei Negativ-Antworten den Versicherer manuell aus der bekannten Liste wählen statt alles abzutippen.
- Vorarbeit für die noch offene Empfängerlogik (§9) beim E-Mail-Versand.

5. Antwort-Zuordnung mit Fallback statt nur exakter Referenz

uebernehmeAntwort findet den Vorgang nur über die (normalisierte) Referenz. Wenn die Referenz in der Mail verstümmelt ist, entsteht ein verwaister neuer Vorgang. Fallback: unter den angefragten Vorgängen nach Gegner-Kennzeichen + Unfalldatum matchen und als „wahrscheinliche Zuordnung — bitte bestätigen" anbieten (bestätigen bleibt beim Anwalt, passt zum Human-in-the-loop-Prinzip).

6. Konflikte sichtbar machen statt still zu verlieren

mitAntwort nimmt Antwortdaten nur, wenn das Vorgangsfeld leer ist (gegner ?? data.versichererName). Weicht die Antwort vom erfassten Wert ab (z. B. anderes Unfalldatum), verschwindet das kommentarlos — dabei gibt es mit ZentralrufReplyWarnings schon die passende Mechanik im Parser. Vorschlag: Abweichungen beim Merge als Warnung am Vorgang anzeigen, mit Wahl „erfassten Wert behalten / Antwortwert übernehmen".

7. Vollständigkeits-Check + Herkunftsanzeige

- Am Vorgang (Tile/Detail) anzeigen, welche Daten für den nächsten Schritt noch fehlen: „Für das Anspruchsschreiben fehlen: Unfallort, Kennzeichen des Mandanten" — bevor der Anwalt im Wizard steht.
- Im Wizard je vorbelegtem Feld die Quelle zeigen (Tooltip „aus Zentralruf-Antwort vom 12.06." / „aus Mandantenregister"). Das schafft Vertrauen in die Automatik und macht falsche Vorbelegungen sofort erkennbar — heute gibt es nur den Sammel-Hinweis „n Felder vorbelegt".