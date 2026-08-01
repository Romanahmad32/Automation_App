using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Options;

namespace AutomationService.Features.PdfConversion.Domain.Services;

public interface IPdfPreviewCache
{
    bool TryGet(string docxFilePath, out byte[] pdfBytes);
    void Put(string docxFilePath, byte[] pdfBytes);
}

/// <summary>
/// Datei-basierter Cache für konvertierte Vorschau-PDFs. Der Schlüssel enthält
/// Pfad, Änderungszeitpunkt und Dateigröße der Quelldatei — wird die Vorlage
/// (z. B. extern in Word) verändert, greift der Cache automatisch nicht mehr.
/// </summary>
public class PdfPreviewCache : IPdfPreviewCache
{
    private const int MaxAgeDays = 14;

    private readonly string _cacheDirectory;
    private readonly ILogger<PdfPreviewCache> _logger;

    public PdfPreviewCache(
        IOptions<PdfConversionOptions> options,
        IHostEnvironment hostEnvironment,
        ILogger<PdfPreviewCache> logger)
        : this(
            Path.GetFullPath(Path.Combine(hostEnvironment.ContentRootPath, options.Value.CacheDirectory)),
            logger)
    {
    }

    /// <summary>Direkter Konstruktor für Tests (beliebiges Cache-Verzeichnis).</summary>
    public PdfPreviewCache(string cacheDirectory, ILogger<PdfPreviewCache> logger)
    {
        _cacheDirectory = cacheDirectory;
        _logger = logger;
        Directory.CreateDirectory(_cacheDirectory);
        CleanupOldEntries();
    }

    public bool TryGet(string docxFilePath, out byte[] pdfBytes)
    {
        pdfBytes = [];
        var cacheFile = CacheFilePathFor(docxFilePath);
        if (cacheFile is null || !File.Exists(cacheFile))
            return false;

        pdfBytes = File.ReadAllBytes(cacheFile);
        return true;
    }

    public void Put(string docxFilePath, byte[] pdfBytes)
    {
        var cacheFile = CacheFilePathFor(docxFilePath);
        if (cacheFile is null)
            return;

        try
        {
            File.WriteAllBytes(cacheFile, pdfBytes);
        }
        catch (IOException exception)
        {
            // Cache ist nur Beschleunigung — Schreibfehler dürfen den Request nicht stören.
            _logger.LogWarning(exception, "PDF-Cache konnte nicht geschrieben werden: {CacheFile}", cacheFile);
        }
    }

    private string? CacheFilePathFor(string docxFilePath)
    {
        var fileInfo = new FileInfo(docxFilePath);
        if (!fileInfo.Exists)
            return null;

        var key = $"{fileInfo.FullName.ToLowerInvariant()}|{fileInfo.LastWriteTimeUtc.Ticks}|{fileInfo.Length}";
        var hash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(key)));
        return Path.Combine(_cacheDirectory, $"{hash}.pdf");
    }

    private void CleanupOldEntries()
    {
        try
        {
            var cutoff = DateTime.UtcNow.AddDays(-MaxAgeDays);
            foreach (var file in Directory.EnumerateFiles(_cacheDirectory, "*.pdf"))
            {
                if (File.GetLastWriteTimeUtc(file) < cutoff)
                    File.Delete(file);
            }
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "Aufräumen des PDF-Caches fehlgeschlagen (unkritisch).");
        }
    }
}
