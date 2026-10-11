namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>Füllt die Vollmacht zu einem Vorgang und druckt oder öffnet sie (§4.11).</summary>
public interface IVollmachtDienst
{
    /// <summary>
    /// Der Stand der drei Vorlagen (<see cref="VollmachtVorlagenOrdner.Stand"/>)
    /// samt ihren Platzhaltern, damit der Dialog nur die Felder zeigt, die auf
    /// der gewählten Vorlage stehen (#171). Jeder Aufruf liest die Dateien neu —
    /// der Anwalt tauscht sie im Explorer, ohne dass die App es erfährt. Eine
    /// Datei, die fehlt, gesperrt oder kaputt ist, hat
    /// <see cref="VollmachtVorlage.Platzhalter"/> null; ein Fehler wird daraus
    /// nicht.
    /// </summary>
    IReadOnlyList<VollmachtVorlage> Vorlagen();

    /// <summary>
    /// Füllt die Vorlage und schickt sie an den Standarddrucker. Nach dem Druck
    /// ist die Arbeitsdatei gelöscht — abgelegt wird nichts. Scheitert der
    /// Druck, bleibt sie liegen und das Ergebnis nennt ihren Pfad.
    /// </summary>
    Task<VollmachtErgebnis> DruckeAsync(VollmachtAuftrag auftrag, CancellationToken cancellationToken = default);

    /// <summary>
    /// Füllt die Vorlage nur aus („In Word öffnen"); die Datei bleibt liegen,
    /// bis der Dialog schließt (<see cref="RaeumeAuf"/>).
    /// </summary>
    VollmachtErgebnis FuelleAus(VollmachtAuftrag auftrag);

    /// <summary>
    /// Löscht die Vollmachtdateien im Arbeitsordner des Vorgangs — die drei
    /// festen Namen, nie ein Anspruchsschreiben daneben; ein danach leerer
    /// Ordner geht mit (§4.11, §8, #174). Hält Word eine Datei noch offen,
    /// bleibt sie still bis zur Startaufräumung liegen.
    /// </summary>
    void RaeumeAuf(string referenz);

    /// <summary>
    /// Füllt aus und liefert die Seite als PDF. Weder die ausgefüllte Datei
    /// noch die PDF bleiben liegen — die Vollmacht wird nicht digital
    /// aufbewahrt (§4.11, §8).
    ///
    /// Bewusst ohne <see cref="CancellationToken"/>: Eine laufende Umwandlung
    /// lässt sich in Word nicht abbrechen, und je Dialog ist höchstens eine
    /// Vorschau unterwegs. Schließt der Anwalt den Dialog vorher, rechnet Word
    /// sie noch zu Ende — rund zwei Sekunden, in denen ein Druck wartet.
    /// </summary>
    Task<VollmachtVorschau> VorschauAsync(VollmachtAuftrag auftrag);
}
