namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Woher eine Zeile des Registers stammt (§6.2). Die Ansicht zeigt beide
/// Quellen in einer Folge — und muss sie trotzdem unterscheiden können: Eine
/// historische Zeile lässt sich nicht öffnen, sondern nur berichtigen, und sie
/// wird grau gezeichnet.
///
/// Als Zeichenkette statt als Enum, weil der Dienst Enums als Zahlen
/// serialisiert — eine Zahl im Vertrag wäre für die Dart-Seite eine stumme
/// Kopplung an die Deklarationsreihenfolge.
/// </summary>
public static class RegisterQuellen
{
    /// <summary>Ein Vorgang, den die App selbst führt.</summary>
    public const string Vorgang = "vorgang";

    /// <summary>Eine übernommene Zeile des gewachsenen Kanzleiregisters ab 2018.</summary>
    public const string Historie = "historie";
}
