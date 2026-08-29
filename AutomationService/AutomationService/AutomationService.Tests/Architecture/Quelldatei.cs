using System.Text.RegularExpressions;

namespace AutomationService.Tests.Architecture;

/// <summary>
/// Eine handgeschriebene C#-Quelldatei mit den Angaben, die die
/// Architektur-Tests brauchen: wo sie liegt, zu welchem Feature-Slice und zu
/// welcher Schicht sie gehoert, und was sie importiert.
/// </summary>
public sealed partial class Quelldatei(string relativerPfad, string absoluterPfad)
{
    string? inhalt;

    /// <summary>Pfad relativ zur Projektwurzel, mit fuehrendem "/".</summary>
    public string RelativerPfad { get; } = relativerPfad;

    public string AbsoluterPfad { get; } = absoluterPfad;

    public string Inhalt => inhalt ??= File.ReadAllText(AbsoluterPfad);

    public int Zeilenzahl => File.ReadAllLines(AbsoluterPfad).Length;

    /// <summary>
    /// Zeilen ohne Leerzeilen und ohne reine Kommentarzeilen -- das Mass, an
    /// dem die Laengenregel haengt (siehe DateilaengeTests).
    ///
    /// Gezaehlt wird, was nach dem Trimmen uebrig bleibt und nicht mit "//",
    /// "/*" oder "*" beginnt. Das erfasst Zeilen- und XML-Kommentare sowie
    /// formatierte Blockkommentare.
    ///
    /// <para>Es ist eine Naeherung, und sie irrt in <b>beide</b> Richtungen.
    /// Zu viel: eine Fliesstextzeile innerhalb eines Blockkommentars, die nicht
    /// mit "*" eingerueckt ist. Zu wenig: jede Zeile innerhalb eines
    /// Zeichenkettenliterals, die mit einem der drei Praefixe beginnt -- eine
    /// URL in einer Rohzeichenkette, eine Aufzaehlung mit "*", eingebetteter
    /// Code mit eigenen Kommentaren (siehe tools/ZentralrufDomDump, das ein
    /// Skript als Rohzeichenkette fuehrt). Eine Datei kann die Grenze also auch
    /// reissen, ohne dass dieser Test es merkt.</para>
    ///
    /// <para>Das ist bewusst in Kauf genommen: Sauber unterscheiden hiesse
    /// tokenisieren, und die Regel ist eine Faustzahl fuer die Lesbarkeit, kein
    /// Beweis. Wer sie schaerfer braucht, faengt bei den Zeichenkettenliteralen
    /// an -- nicht bei den Kommentarpraefixen.</para>
    /// </summary>
    public int Anweisungszeilen =>
        File.ReadAllLines(AbsoluterPfad).Count(IstAnweisungszeile);

    /// <summary>
    /// Dieselbe Zaehlweise wie in dart_source_files.dart im Frontend. Wer eine
    /// der beiden aendert, aendert die andere mit -- sonst gilt fuer dieselbe
    /// Regel auf beiden Seiten eine andere Zahl.
    /// </summary>
    public static bool IstAnweisungszeile(string zeile)
    {
        var inhalt = zeile.AsSpan().Trim();
        if (inhalt.IsEmpty) return false;

        return !inhalt.StartsWith("//")
            && !inhalt.StartsWith("/*")
            && !inhalt.StartsWith("*");
    }

    /// <summary>
    /// Name des Feature-Slices (Ordner unter Features/) oder null, wenn die
    /// Datei ausserhalb von Features/ liegt (Core, Program.cs, Tests).
    /// </summary>
    public string? Feature => FeaturePfad().Match(RelativerPfad) is { Success: true } treffer
        ? treffer.Groups[1].Value
        : null;

    /// <summary>
    /// Schicht innerhalb des Slices: "Domain" oder "Presentation".
    /// Null ausserhalb von Features/.
    /// </summary>
    public string? Schicht => FeaturePfad().Match(RelativerPfad) is { Success: true } treffer
        ? treffer.Groups[2].Value
        : null;

    /// <summary>
    /// Alle per using importierten Namespaces der Datei.
    /// </summary>
    public IReadOnlyList<string> Usings =>
        UsingZeile().Matches(Inhalt).Select(t => t.Groups[1].Value).ToList();

    /// <summary>
    /// True, wenn die Datei ueberhaupt einen Typ deklariert. Dateien, die nur
    /// Assembly-Attribute enthalten, koennen gar keinen Namespace haben und
    /// sind von der Namespace-Konvention ausgenommen.
    /// </summary>
    public bool DeklariertTyp => TypDeklaration().IsMatch(Inhalt);

    /// <summary>
    /// Der in der Datei deklarierte Namespace, oder null wenn keiner da ist.
    /// </summary>
    public string? Namespace =>
        NamespaceZeile().Match(Inhalt) is { Success: true } treffer
            ? treffer.Groups[1].Value
            : null;

    public override string ToString() => RelativerPfad;

    [GeneratedRegex(@"^/Features/([^/]+)/([^/]+)/")]
    private static partial Regex FeaturePfad();

    [GeneratedRegex(@"^using\s+(?:static\s+)?([A-Za-z_][A-Za-z0-9_.]*)\s*;", RegexOptions.Multiline)]
    private static partial Regex UsingZeile();

    [GeneratedRegex(@"^namespace\s+([A-Za-z_][A-Za-z0-9_.]*)", RegexOptions.Multiline)]
    private static partial Regex NamespaceZeile();

    [GeneratedRegex(
        @"^\s*(?:\[[^\]]*\]\s*)*(?:public|internal|private|protected|static|sealed|abstract|partial|file|\s)*\b(class|record|struct|interface|enum|delegate)\b",
        RegexOptions.Multiline)]
    private static partial Regex TypDeklaration();
}
