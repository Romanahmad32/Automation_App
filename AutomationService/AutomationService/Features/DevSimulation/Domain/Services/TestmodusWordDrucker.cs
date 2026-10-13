using AutomationService.Features.PdfConversion.Domain.Services;

namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Druck im E2E-Testmodus (#168): kein Word, kein Papier. Die Datei, die Word
/// drucken würde, landet als Kopie unter
/// <c>Testmodus\Druck\&lt;zeit&gt;_&lt;Originalname&gt;.docx</c>.
///
/// <b>Kopiert wird, bevor die Methode zurückkehrt.</b> Der Aufrufer
/// (<c>VollmachtDienst.DruckeAsync</c>) löscht die Arbeitsdatei unmittelbar
/// nach dem Druck — eine Kopie, die erst danach versucht würde, fände nichts
/// mehr.
///
/// Als Drucker meldet sie <see cref="Druckername"/>, damit der Dialog sagt,
/// dass nichts gedruckt wurde.
/// </summary>
public sealed class TestmodusWordDrucker(TestmodusOrdner ordner, TestmodusProtokoll protokoll) : IWordDrucker
{
    /// <summary>
    /// Steht im Vollmacht-Dialog vor dem Druck („Drucker: …") und danach („an …
    /// übergeben") — dieselbe Angabe in <see cref="TestmodusDruckerAuskunft"/>.
    /// </summary>
    public const string Druckername = "Testmodus (kein Druck)";

    public Task<string?> DruckeAsync(string docxPfad, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(docxPfad);
        cancellationToken.ThrowIfCancellationRequested();

        var ziel = ordner.NeueDatei(
            TestmodusOrdner.Druck,
            Path.GetExtension(docxPfad),
            zusatz: Path.GetFileNameWithoutExtension(docxPfad));
        File.Copy(docxPfad, ziel, overwrite: true);
        protokoll.Schreibe(TestmodusProtokoll.Druck, referenz: null, ordner.Relativ(ziel));

        return Task.FromResult<string?>(Druckername);
    }
}
