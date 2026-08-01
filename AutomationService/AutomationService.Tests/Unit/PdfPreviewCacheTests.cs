using AutomationService.Features.PdfConversion.Domain.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace AutomationService.Tests.Unit;

public sealed class PdfPreviewCacheTests : IDisposable
{
    private readonly string _workDirectory =
        Path.Combine(Path.GetTempPath(), $"PdfPreviewCacheTests_{Guid.NewGuid():N}");

    private readonly string _cacheDirectory;

    public PdfPreviewCacheTests()
    {
        _cacheDirectory = Path.Combine(_workDirectory, "cache");
        Directory.CreateDirectory(_workDirectory);
    }

    public void Dispose() => Directory.Delete(_workDirectory, recursive: true);

    private PdfPreviewCache CreateCache() =>
        new(_cacheDirectory, NullLogger<PdfPreviewCache>.Instance);

    private string CreateDocxFile(string name = "vorlage.docx", string content = "docx-inhalt")
    {
        var path = Path.Combine(_workDirectory, name);
        File.WriteAllText(path, content);
        return path;
    }

    [Fact]
    public void TryGet_WithoutPriorPut_ReturnsFalse()
    {
        var cache = CreateCache();
        var docxPath = CreateDocxFile();

        cache.TryGet(docxPath, out _).Should().BeFalse();
    }

    [Fact]
    public void TryGet_AfterPut_ReturnsCachedBytes()
    {
        var cache = CreateCache();
        var docxPath = CreateDocxFile();
        byte[] pdfBytes = [1, 2, 3, 4];

        cache.Put(docxPath, pdfBytes);

        cache.TryGet(docxPath, out var cached).Should().BeTrue();
        cached.Should().Equal(pdfBytes);
    }

    [Fact]
    public void TryGet_AfterSourceFileChanged_ReturnsFalse()
    {
        var cache = CreateCache();
        var docxPath = CreateDocxFile();
        cache.Put(docxPath, [1, 2, 3]);

        // Externe Bearbeitung simulieren: anderer Inhalt + neuer Zeitstempel.
        File.WriteAllText(docxPath, "geänderter inhalt");
        File.SetLastWriteTimeUtc(docxPath, DateTime.UtcNow.AddMinutes(5));

        cache.TryGet(docxPath, out _).Should().BeFalse();
    }

    [Fact]
    public void TryGet_ForMissingSourceFile_ReturnsFalse()
    {
        var cache = CreateCache();

        cache.TryGet(Path.Combine(_workDirectory, "gibt-es-nicht.docx"), out _).Should().BeFalse();
    }

    [Fact]
    public void Constructor_DeletesCacheEntriesOlderThanTwoWeeks()
    {
        Directory.CreateDirectory(_cacheDirectory);
        var oldEntry = Path.Combine(_cacheDirectory, "alt.pdf");
        var freshEntry = Path.Combine(_cacheDirectory, "frisch.pdf");
        File.WriteAllBytes(oldEntry, [1]);
        File.WriteAllBytes(freshEntry, [2]);
        File.SetLastWriteTimeUtc(oldEntry, DateTime.UtcNow.AddDays(-30));

        CreateCache();

        File.Exists(oldEntry).Should().BeFalse();
        File.Exists(freshEntry).Should().BeTrue();
    }
}
