namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Was mit einer Zeile der Importdatei geschieht. Als Zeichenkette statt als
/// Enum, weil der Dienst Enums als Zahlen serialisiert — eine Zahl im Vertrag
/// wäre für die Dart-Seite eine stumme Kopplung an die Deklarationsreihenfolge.
/// </summary>
public static class ImportArten
{
    /// <summary>Der Mandant ist neu und wird angelegt.</summary>
    public const string Neu = "neu";

    /// <summary>Vorhandener Mandant, es kommen Ordner, Kennzeichen oder leere Felder dazu.</summary>
    public const string Ergaenzt = "ergaenzt";

    /// <summary>Vorhandener Mandant, die Datei bringt nichts Neues.</summary>
    public const string Unveraendert = "unveraendert";

    /// <summary>Die Zeile wird nicht übernommen; der Grund steht in den Hinweisen.</summary>
    public const string Abgelehnt = "abgelehnt";
}

/// <summary>
/// Das Ergebnis für eine einzelne Zeile der Datei. <c>Zeile</c> ist die
/// Position in <c>mandanten</c> ab 0 — der Bezug zurück in die Datei.
/// <c>AktenOrdnernamen</c> sind die Ordner, die dieser Mandant durch den Import
/// wirklich bekommt: was schon einem anderen gehört, steht nicht hier, sondern
/// als Hinweis daneben.
/// </summary>
public sealed record ImportEintragBefund(
    int Zeile,
    string Anzeigename,
    IReadOnlyList<string> AktenOrdnernamen,
    string Art,
    int? MandantId,
    string Sicherheit,
    string Quelle,
    IReadOnlyList<string> Hinweise);

/// <summary>
/// Der Bericht über einen Import — bei der Vorschau und beim Übernehmen
/// derselbe Typ mit demselben Inhalt, nur <see cref="Angewendet"/>
/// unterscheidet sie.
/// </summary>
public sealed record MandantenImportBefund(
    IReadOnlyList<ImportEintragBefund> Eintraege,
    int Neu,
    int Ergaenzt,
    int Unveraendert,
    int Abgelehnt,
    int OrdnerZugeordnet,
    int OhneMandantenbezug,
    bool Angewendet);
