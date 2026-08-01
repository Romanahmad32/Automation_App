using Xceed.Document.NET;
using Xceed.Words.NET;

namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Kreuzt im Block "Mein Mandant ☐ ist / ☐ ist nicht vorsteuerabzugsberechtigt"
/// das passende Kästchen an.
///
/// Die Vorlagen kreuzen auf zwei Arten an: (a) literale Unicode-Kästchen
/// (☐ U+2610 / ☒ U+2612) im Fließtext oder (b) Word-Kontrollkästchen
/// (Inhaltssteuerelement &lt;w:sdt&gt; mit &lt;w14:checkbox&gt;), bei denen
/// Zustand (&lt;w14:checked&gt;) und angezeigtes Glyph getrennt gesetzt werden
/// müssen. Beide Wege werden bedient.
/// </summary>
public static class VorsteuerCheckbox
{
    private const char CheckedBox = '☒'; // U+2612
    private const char EmptyBox = '☐';   // U+2610
    private const string Anchor = "vorsteuerabzugsberechtigt";

    /// <summary>
    /// Setzt die Kästchen des Vorsteuer-Blocks. Da es keine Platzhalter gibt,
    /// wird der Block heuristisch über den Anker "vorsteuerabzugsberechtigt"
    /// gefunden. Anker und Kästchen können in getrennten Absätzen stehen;
    /// deshalb wird ab dem Anker rückwärts ein kleines Fenster nach den beiden
    /// Kästchen-Absätzen durchsucht und über das Wort "nicht" in Positiv-/
    /// Negativ-Zeile klassifiziert.
    /// </summary>
    /// <returns>false, wenn die Vorlage keinen solchen Block enthält.</returns>
    public static bool Apply(DocX document, bool vorsteuerabzugsberechtigt)
    {
        ArgumentNullException.ThrowIfNull(document);

        var paragraphs = document.Paragraphs;

        var anchorIndex = -1;
        for (var i = 0; i < paragraphs.Count; i++)
        {
            if (paragraphs[i].Text.Contains(Anchor, StringComparison.OrdinalIgnoreCase))
            {
                anchorIndex = i;
                break;
            }
        }
        if (anchorIndex < 0)
            return false;

        Paragraph? positive = null;
        Paragraph? negative = null;
        for (var i = anchorIndex; i >= 0 && i >= anchorIndex - 8; i--)
        {
            var paragraph = paragraphs[i];
            if (!HasCheckbox(paragraph))
                continue;

            // Negativ-Zeile = "… ist nicht …", Positiv-Zeile = "… ist".
            if (paragraph.Text.Contains("nicht", StringComparison.OrdinalIgnoreCase))
                negative ??= paragraph;
            else
                positive ??= paragraph;

            if (positive is not null && negative is not null)
                break;
        }

        if (negative is null)
            return false;

        // "ist nicht vorsteuerabzugsberechtigt" ist angekreuzt, wenn der Mandant
        // gerade NICHT vorsteuerabzugsberechtigt ist – und umgekehrt.
        SetState(negative, isChecked: !vorsteuerabzugsberechtigt);
        if (positive is not null)
            SetState(positive, isChecked: vorsteuerabzugsberechtigt);

        return true;
    }

    /// <summary>True, wenn der Absatz ein literales Kästchen-Glyph oder ein
    /// Word-Kontrollkästchen (w14:checkbox) enthält.</summary>
    private static bool HasCheckbox(Paragraph paragraph)
    {
        if (paragraph.Text.Contains(EmptyBox) || paragraph.Text.Contains(CheckedBox))
            return true;
        return paragraph.Xml.Descendants().Any(element => element.Name.LocalName == "checkbox");
    }

    /// <summary>
    /// Setzt den Zustand des Kästchens im Absatz. Bei Word-Kontrollkästchen werden
    /// sowohl &lt;w14:checked&gt; als auch das angezeigte Glyph gesetzt; sonst wird
    /// das literale Glyph ersetzt (No-op, wenn bereits korrekt).
    /// </summary>
    private static void SetState(Paragraph paragraph, bool isChecked)
    {
        var glyph = isChecked ? CheckedBox : EmptyBox;

        var checkboxSdts = paragraph.Xml
            .Descendants()
            .Where(element => element.Name.LocalName == "sdt"
                && element.Descendants().Any(child => child.Name.LocalName == "checkbox"))
            .ToList();

        if (checkboxSdts.Count > 0)
        {
            foreach (var sdt in checkboxSdts)
            {
                var checkedElement = sdt.Descendants()
                    .FirstOrDefault(element => element.Name.LocalName == "checked");
                var valAttribute = checkedElement?.Attributes()
                    .FirstOrDefault(attribute => attribute.Name.LocalName == "val");
                if (valAttribute is not null)
                    valAttribute.Value = isChecked ? "1" : "0";

                var sdtContent = sdt.Elements()
                    .FirstOrDefault(element => element.Name.LocalName == "sdtContent");
                var textElement = sdtContent?.Descendants()
                    .FirstOrDefault(element => element.Name.LocalName == "t");
                textElement?.SetValue(glyph.ToString());
            }
            return;
        }

        // Literales Glyph: das jeweils andere Kästchen durch das gewünschte ersetzen.
        var other = isChecked ? EmptyBox : CheckedBox;
        paragraph.ReplaceText(new StringReplaceTextOptions
        {
            SearchValue = other.ToString(),
            NewValue = glyph.ToString(),
            EscapeRegEx = true,
            StopAfterOneReplacement = true
        });
    }
}
