using System.Text;
using AutomationService.Features.PdfConversion.Domain.Services;

namespace AutomationService.Tests.Support;

/// <summary>
/// Ersetzt die PDF-Wandlung in Tests. Der echte Weg ruft Microsoft Word über
/// COM — auf einem Rechner ohne Word gäbe es den Test gar nicht, und mit Word
/// dauerte er Sekunden.
///
/// <see cref="Wirft"/> bildet genau diesen Rechner ohne Word nach: Dann muss
/// die .docx trotzdem geschrieben werden, denn sie ist die verbindliche
/// Fassung — das PDF ist die bequeme.
/// </summary>
public sealed class PdfAttrappe : IPdfConversionService
{
    public const string Inhalt = "%PDF-Attrappe";

    public Exception? Wirft { get; set; }

    public int Aufrufe { get; private set; }

    public Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath)
    {
        Aufrufe++;
        if (Wirft is not null) throw Wirft;
        return Task.FromResult(Encoding.UTF8.GetBytes(Inhalt));
    }

    public Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes) =>
        ConvertDocxToPdfAsync(string.Empty);
}
