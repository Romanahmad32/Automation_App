namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Wendet die <see cref="Aufbewahrungsregel"/> auf den Ablageordner an
/// (§7.2, #112) — der einzige Ort, an dem automatische Sicherungen gelöscht
/// werden.
///
/// <para>
/// <b>Nur die eigenen.</b> Beide Arbeitsplätze legen in denselben Ordner. Ein
/// Rechner, der auch die Historie des anderen wegräumte, nähme ihm genau das,
/// was dieser zur Übergabe braucht — deshalb geht alles über das Suchmuster mit
/// dem eigenen Rechnernamen und zusätzlich über den Namensprüfer im
/// <see cref="SicherungsDateiname"/>.
/// </para>
/// </summary>
public static class SicherungsAufraeumung
{
    /// <summary>
    /// Räumt auf und liefert, wie viele Archive gelöscht wurden.
    ///
    /// Wirft nie: Aufräumen ist Kür. Scheitert es an einer Datei — der
    /// Synchronisierer hält sie gerade offen, die Rechte fehlen —, bleibt sie
    /// liegen und der nächste Lauf versucht es erneut. Ein Abbruch hier machte
    /// aus einer gelungenen Sicherung eine misslungene.
    /// </summary>
    public static int RaeumeAuf(string ordner, string rechnername, DateTime jetzt)
    {
        var geloescht = 0;
        foreach (var pfad in Aufbewahrungsregel.ZuLoeschen(
                     SicherungsBestand.Archive(ordner, rechnername), jetzt))
        {
            try
            {
                File.Delete(pfad);
                geloescht++;
            }
            catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
            {
                // Eine Datei zu viel im Ordner ist kein Schaden; ein Abbruch wäre einer.
            }
        }

        return geloescht;
    }
}
