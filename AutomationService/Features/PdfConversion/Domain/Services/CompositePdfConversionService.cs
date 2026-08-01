using Microsoft.Extensions.Options;

namespace AutomationService.Features.PdfConversion.Domain.Services;

/// <summary>
/// Orchestriert die PDF-Konvertierung: erst Cache, dann die konfigurierte Engine
/// (Word-Interop für originalgetreues Druckbild), bei Nichtverfügbarkeit von Word
/// automatischer Fallback auf FreeSpire.
/// </summary>
public class CompositePdfConversionService(
    IWordInteropPdfConverter wordConverter,
    [FromKeyedServices(CompositePdfConversionService.FreeSpireKey)] IPdfConversionService freeSpireConverter,
    IPdfPreviewCache cache,
    IOptions<PdfConversionOptions> options,
    ILogger<CompositePdfConversionService> logger) : IPdfConversionService
{
    public const string FreeSpireKey = "FreeSpire";

    public async Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath)
    {
        if (cache.TryGet(docxFilePath, out var cachedPdf))
        {
            logger.LogDebug("PDF-Cache-Treffer für {DocxFilePath}.", docxFilePath);
            return cachedPdf;
        }

        var pdfBytes = await ConvertUncachedAsync(docxFilePath);
        cache.Put(docxFilePath, pdfBytes);
        return pdfBytes;
    }

    public async Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes)
    {
        if (docxBytes == null || docxBytes.Length == 0)
            throw new ArgumentException("Input DOCX bytes cannot be null or empty.");

        var tempDocxPath = Path.Combine(Path.GetTempPath(), $"{Guid.NewGuid()}.docx");
        try
        {
            await File.WriteAllBytesAsync(tempDocxPath, docxBytes);
            // Temp-Dateien sind Einmal-Inhalte — bewusst am Cache vorbei.
            return await ConvertUncachedAsync(tempDocxPath);
        }
        finally
        {
            File.Delete(tempDocxPath);
        }
    }

    private async Task<byte[]> ConvertUncachedAsync(string docxFilePath)
    {
        if (options.Value.Engine != PdfConversionOptions.EngineWordInterop || wordConverter.IsAvailable == false)
            return await ConvertWithFreeSpireAsync(docxFilePath, wordFailure: null);

        try
        {
            return await wordConverter.ConvertDocxToPdfAsync(docxFilePath);
        }
        catch (FileNotFoundException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception,
                "Word-Interop-Konvertierung fehlgeschlagen, versuche FreeSpire-Fallback für {DocxFilePath}.",
                docxFilePath);
            return await ConvertWithFreeSpireAsync(docxFilePath, exception);
        }
    }

    private async Task<byte[]> ConvertWithFreeSpireAsync(string docxFilePath, Exception? wordFailure)
    {
        try
        {
            return await freeSpireConverter.ConvertDocxToPdfAsync(docxFilePath);
        }
        catch (FileNotFoundException)
        {
            throw;
        }
        catch (Exception exception)
        {
            throw new PdfConversionUnavailableException(
                "PDF-Vorschau nicht verfügbar: Die Konvertierung ist mit allen Engines fehlgeschlagen. " +
                "Bitte prüfen, ob Microsoft Word installiert ist.",
                wordFailure ?? exception);
        }
    }
}
