namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die Signatur der Kanzlei, wie sie in den Einstellungen liegt (§4.7) — in
/// beiden Fassungen, die eine Mail braucht.
///
/// <see cref="Html"/> ist die übernommene Fassung aus Outlook, mit Schrift,
/// Farben und Bildern. <see cref="Text"/> ist Outlooks eigene Nur-Text-Übersetzung
/// derselben Signatur; sie geht als Alternative mit, für Empfänger, die kein
/// HTML anzeigen, und sie ist es, die die App in ihrer Vorschau zeigt.
///
/// Ohne HTML-Fassung bleibt alles beim Alten: Die Mail geht als reiner Text
/// hinaus.
/// </summary>
public sealed record SignaturBlock(
    string Text,
    string Html,
    IReadOnlyList<SignaturBild> Bilder)
{
    public static readonly SignaturBlock Keiner = new(string.Empty, string.Empty, []);

    public bool Leer => Text.Length == 0 && Html.Length == 0;

    /// <summary>Wie viel die Bilder zusammen wiegen — zählt zur Nachrichtengröße.</summary>
    public long BilderBytes => Bilder.Sum(bild => bild.Bytes);
}

/// <summary>
/// Die Signatur, fertig für genau eine Nachricht: die Bilder, die der Anwalt
/// für diese Mail behalten hat, bereits zu Pfaden aufgelöst.
/// </summary>
/// <param name="Text">Nur-Text-Fassung für den Alternativteil.</param>
/// <param name="Html">HTML-Fassung; leer, wenn keine übernommen wurde.</param>
/// <param name="BildPfade">
/// Vollständige Pfade der mitgehenden Bilder. Was der Anwalt für diese Mail
/// verworfen hat, steht nicht darin — und die HTML-Fassung verliert dann
/// dessen Bildverweis.
/// </param>
public sealed record SignaturVersand(
    string Text,
    string Html,
    IReadOnlyList<string> BildPfade);
