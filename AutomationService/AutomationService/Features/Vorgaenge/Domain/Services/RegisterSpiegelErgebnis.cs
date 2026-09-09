namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Was beim Schreiben des Register-Spiegels herauskam (§6.2, #40).
///
/// Ein Ergebnis statt einer Ausnahme, weil der häufigste Fehlerfall — das
/// Register ist gerade in Word geöffnet — kein Programmfehler ist, sondern
/// eine Lage, die die Oberfläche erklären und der Anwender in fünf Sekunden
/// beheben kann. Vor allem aber darf er den Vorgangsabschluss nicht mitreißen,
/// nach dem der Spiegel läuft.
/// </summary>
/// <param name="Geschrieben">Ob in diesem Lauf Dateien entstanden sind.</param>
/// <param name="Grund">
/// Warum nicht geschrieben wurde — kein Ablageordner eingestellt, oder der
/// Bestand ist unverändert. Null, wenn geschrieben wurde.
/// </param>
/// <param name="Fehler">
/// Klartext für die Oberfläche, wenn das Schreiben scheiterte. Null sonst.
/// </param>
/// <param name="DocxPfad">Die geschriebene Word-Datei; null, wenn keine entstand.</param>
/// <param name="PdfPfad">
/// Die abgelegte PDF-Datei; null, wenn keine liegt. Direkt nach einem
/// Schreiblauf ist das der Normalfall — die Fassung entsteht erst danach
/// (§6.2 „Word sofort, PDF nachgezogen"), und was dann zählt, ist
/// <see cref="PdfLaeuft"/>.
/// </param>
/// <param name="PdfFehler">
/// Warum das PDF fehlt, obwohl die .docx steht — auf einem Rechner ohne Word
/// ist das ein erwartbarer Zustand und kein Grund, den Spiegel als
/// gescheitert zu melden. Null, solange die Fassung noch entsteht: „noch nicht
/// da" ist kein Fehler und darf nicht als einer erscheinen.
/// </param>
/// <param name="PdfLaeuft">
/// Ob gerade eine PDF-Fassung entsteht (§6.2: „Dass ein PDF gerade entsteht,
/// ist an der Oberfläche ablesbar"). Gilt für den ganzen Prozess und nicht nur
/// für diesen Aufruf — wer die Registerseite nach einem Fensterwechsel neu
/// öffnet, sieht den laufenden Lauf weiterhin.
/// </param>
/// <param name="Zeilen">Anzahl der Registerzeilen in der Datei.</param>
/// <param name="GeschriebenAm">Zeitpunkt des letzten erfolgreichen Schreibens.</param>
/// <param name="Konfliktkopien">
/// Dateien im Ablageordner, die nach einer vom Synchronisierungsdienst
/// angelegten Konfliktkopie aussehen. Ihr Auftauchen heißt: Jemand hat den
/// Spiegel unterwegs bearbeitet — ab da gäbe es zwei Register, und genau davor
/// soll die Oberfläche warnen.
/// </param>
public sealed record RegisterSpiegelErgebnis(
    bool Geschrieben,
    string? Grund,
    string? Fehler,
    string? DocxPfad,
    string? PdfPfad,
    string? PdfFehler,
    bool PdfLaeuft,
    int Zeilen,
    DateTime? GeschriebenAm,
    IReadOnlyList<string> Konfliktkopien)
{
    /// <summary>
    /// Es gab nichts zu tun — kein Ablageordner eingestellt, oder der Bestand
    /// ist unverändert.
    ///
    /// <see cref="Konfliktkopien"/> wird durchgereicht und nicht weggelassen:
    /// Eine Warnung, die nur auf dem Erfolgsweg erscheint, fehlt gerade dann,
    /// wenn der Anwender sie braucht — ein übersprungener Lauf ist der
    /// Normalfall, und die Konfliktkopie daneben verschwindet dadurch nicht.
    ///
    /// <see cref="PdfLaeuft"/> bleibt hier <c>false</c> und wird erst am
    /// Ausgang des Dienstes gesetzt — an einer Stelle, aus einer Quelle
    /// (siehe <c>RegisterSpiegelService</c>).
    /// </summary>
    public static RegisterSpiegelErgebnis Uebersprungen(
        string grund, int zeilen, DateTime? zuletzt, IReadOnlyList<string>? konfliktkopien = null) =>
        new(false, grund, null, null, null, null, false, zeilen, zuletzt, konfliktkopien ?? []);

    /// <summary>
    /// Das Schreiben scheiterte an einer Lage, die der Anwender beheben kann.
    /// <see cref="Konfliktkopien"/> wird aus demselben Grund durchgereicht wie
    /// bei <see cref="Uebersprungen"/>, <see cref="PdfLaeuft"/> aus demselben
    /// Grund nicht gesetzt.
    /// </summary>
    public static RegisterSpiegelErgebnis Gescheitert(
        string fehler, int zeilen, DateTime? zuletzt, IReadOnlyList<string>? konfliktkopien = null) =>
        new(false, null, fehler, null, null, null, false, zeilen, zuletzt, konfliktkopien ?? []);
}
