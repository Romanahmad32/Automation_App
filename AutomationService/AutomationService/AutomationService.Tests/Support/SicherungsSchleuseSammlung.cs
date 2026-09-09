using Xunit;

namespace AutomationService.Tests.Support;

/// <summary>
/// Klammert alle Testklassen, die eine echte Sicherung schreiben oder einen
/// Stand übernehmen, und reiht sie hintereinander.
///
/// Nicht aus Bequemlichkeit: <c>SynchronisationsVerlauf.Schleuse</c> und
/// <c>DatenbankWechsel.Schleuse</c> sind <em>statisch</em> — sie schützen den
/// Ablageordner und die Datenbankdatei prozessweit, also über die ganze
/// Test-Assembly hinweg und nicht je Instanz. Laufen zwei solche Klassen
/// gleichzeitig an, wartet die eine hinter dem Archivbau der anderen. Für
/// Tests, die nur auf ein Ergebnis warten, fällt das nicht auf; ein Test mit
/// einer Frist (<c>SicherungsZeitgeberStartTests</c> wartet auf den ersten
/// Takt) läuft dagegen sporadisch in seinen Timeout — ein Fehler im
/// Testaufbau, der als flatterhaftes CI erscheint und dann als solches
/// abgetan wird.
///
/// Bewusst <em>ohne</em> <c>DisableParallelization</c>: Die Klassen hier
/// behindern einander, nicht den Rest der Suite. xUnit reiht Klassen derselben
/// Sammlung ohnehin hintereinander und lässt andere Sammlungen daneben weiter
/// laufen — genau das ist gewollt.
///
/// Wer eine Testklasse schreibt, die <c>AutomatischeSicherung</c>,
/// <c>ArbeitsplatzUebergabe</c> oder den <c>SicherungsZeitgeber</c> gegen echte
/// Dateien fährt, trägt sie hier ein:
/// <c>[Collection(SicherungsSchleuseSammlung.Name)]</c>.
/// </summary>
[CollectionDefinition(Name)]
public sealed class SicherungsSchleuseSammlung
{
    public const string Name = "Sicherungs-Schleuse";
}
