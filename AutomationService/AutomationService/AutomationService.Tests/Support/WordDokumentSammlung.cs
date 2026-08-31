using Xunit;

namespace AutomationService.Tests.Support;

/// <summary>
/// Klammert alle Testklassen, die eine <c>.docx</c> über Xceed/DocX bauen, und
/// nimmt sie aus der Parallelität heraus.
///
/// Nicht aus Bequemlichkeit: <c>DocX.Create</c> hält beim Anlegen eines
/// Dokuments prozessweiten Zustand (die Content-Type-Tabelle des geöffneten
/// Pakets). Laufen zwei solche Klassen gleichzeitig an, scheitert eine davon
/// sporadisch mit „An item with the same key has already been added. Key:
/// rels" — ein Fehler im Testaufbau, nicht in der Fachlogik, der ohne diese
/// Klammer als gelegentlich rotes CI erscheint und dann als Flatterhaftigkeit
/// abgetan wird.
///
/// Wer eine Testklasse schreibt, die Word-Dokumente erzeugt, trägt sie hier
/// ein: <c>[Collection(WordDokumentSammlung.Name)]</c>.
/// </summary>
[CollectionDefinition(Name, DisableParallelization = true)]
public sealed class WordDokumentSammlung
{
    public const string Name = "Word-Dokumente";
}
