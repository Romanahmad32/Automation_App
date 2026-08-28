namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die formatierte Fassung einer Outlook-Signatur, wie sie aus dem Beiordner
/// gelesen wurde (§4.7).
///
/// Eigener Typ statt eines Tupels wegen des dritten Feldes: Ein Bild, das nicht
/// mitgenommen werden konnte, ist keine Nebensache, die man in einer
/// namenlosen Stelle unterbringt — es fehlt beim Empfänger, und er muss es
/// erfahren.
/// </summary>
/// <param name="Html">Der Rumpf, Bildverweise auf den blanken Dateinamen gekürzt.</param>
/// <param name="Bilder">Die eingesammelten Bilder, je Dateiname ihr Inhalt.</param>
/// <param name="Uebergangen">
/// Verweise auf Dateien, die <b>nicht</b> mitgenommen werden konnten — zu groß
/// (<see cref="SignaturAblage.MaxBildBytes"/>), nicht lesbar oder nicht mehr da.
/// Ihre Bildmarken sind aus <paramref name="Html"/> entfernt: Ein Verweis auf
/// eine Datei, die nicht mitgeht, wäre beim Empfänger ein Platzhalterkreuz —
/// und das sähe nach einem Fehler aus, den niemand erklärt hat. Der Anwalt
/// erfährt beim Übernehmen, welche fehlen.
/// </param>
public sealed record OutlookSignaturFormat(
    string Html,
    Dictionary<string, byte[]> Bilder,
    IReadOnlyList<string> Uebergangen);
