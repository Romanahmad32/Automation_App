using AutomationService.Features.PdfConversion.Domain.Services;
using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace AutomationService.Tests.Unit;

public class CompositePdfConversionServiceTests
{
    private static readonly byte[] WordPdf = [1, 1, 1];
    private static readonly byte[] FreeSpirePdf = [2, 2, 2];

    private sealed class FakeWordConverter : IWordInteropPdfConverter
    {
        public bool? IsAvailable { get; set; } = true;
        public Exception? ThrowOnConvert { get; set; }
        public int ConvertCalls { get; private set; }

        public Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath, CancellationToken cancellationToken = default)
        {
            ConvertCalls++;
            return ThrowOnConvert is null ? Task.FromResult(WordPdf) : Task.FromException<byte[]>(ThrowOnConvert);
        }

        public Task WarmupAsync() => Task.CompletedTask;
    }

    private sealed class FakeFreeSpireConverter : IPdfConversionService
    {
        public Exception? ThrowOnConvert { get; set; }
        public int ConvertCalls { get; private set; }

        public Task<byte[]> ConvertDocxToPdfAsync(string docxFilePath)
        {
            ConvertCalls++;
            return ThrowOnConvert is null
                ? Task.FromResult(FreeSpirePdf)
                : Task.FromException<byte[]>(ThrowOnConvert);
        }

        public Task<byte[]> ConvertDocxToPdfFromBytesAsync(byte[] docxBytes) =>
            ConvertDocxToPdfAsync("(bytes)");
    }

    private sealed class FakePdfPreviewCache : IPdfPreviewCache
    {
        private readonly Dictionary<string, byte[]> _entries = [];

        public bool TryGet(string docxFilePath, out byte[] pdfBytes) =>
            _entries.TryGetValue(docxFilePath, out pdfBytes!);

        public void Put(string docxFilePath, byte[] pdfBytes) => _entries[docxFilePath] = pdfBytes;
    }

    private readonly FakeWordConverter _wordConverter = new();
    private readonly FakeFreeSpireConverter _freeSpireConverter = new();
    private readonly FakePdfPreviewCache _cache = new();

    private CompositePdfConversionService CreateService(string engine = PdfConversionOptions.EngineWordInterop) =>
        new(
            _wordConverter,
            _freeSpireConverter,
            _cache,
            Options.Create(new PdfConversionOptions { Engine = engine }),
            NullLogger<CompositePdfConversionService>.Instance);

    [Fact]
    public async Task UsesWordInterop_WhenEngineIsWordInterop()
    {
        var result = await CreateService().ConvertDocxToPdfAsync("egal.docx");

        result.Should().Equal(WordPdf);
        _freeSpireConverter.ConvertCalls.Should().Be(0);
    }

    [Fact]
    public async Task ReturnsCachedPdf_WithoutCallingAnyEngine()
    {
        byte[] cached = [9, 9];
        _cache.Put("egal.docx", cached);

        var result = await CreateService().ConvertDocxToPdfAsync("egal.docx");

        result.Should().Equal(cached);
        _wordConverter.ConvertCalls.Should().Be(0);
        _freeSpireConverter.ConvertCalls.Should().Be(0);
    }

    [Fact]
    public async Task CachesResult_AfterSuccessfulConversion()
    {
        var service = CreateService();

        await service.ConvertDocxToPdfAsync("egal.docx");
        await service.ConvertDocxToPdfAsync("egal.docx");

        _wordConverter.ConvertCalls.Should().Be(1);
    }

    [Fact]
    public async Task FallsBackToFreeSpire_WhenWordConversionFails()
    {
        _wordConverter.ThrowOnConvert = new InvalidOperationException("Word abgestürzt");

        var result = await CreateService().ConvertDocxToPdfAsync("egal.docx");

        result.Should().Equal(FreeSpirePdf);
    }

    [Fact]
    public async Task UsesFreeSpireDirectly_WhenWordIsKnownUnavailable()
    {
        _wordConverter.IsAvailable = false;

        var result = await CreateService().ConvertDocxToPdfAsync("egal.docx");

        result.Should().Equal(FreeSpirePdf);
        _wordConverter.ConvertCalls.Should().Be(0);
    }

    [Fact]
    public async Task UsesFreeSpireDirectly_WhenEngineIsFreeSpire()
    {
        var result = await CreateService(PdfConversionOptions.EngineFreeSpire)
            .ConvertDocxToPdfAsync("egal.docx");

        result.Should().Equal(FreeSpirePdf);
        _wordConverter.ConvertCalls.Should().Be(0);
    }

    [Fact]
    public async Task ThrowsUnavailable_WhenBothEnginesFail()
    {
        _wordConverter.ThrowOnConvert = new InvalidOperationException("Word kaputt");
        _freeSpireConverter.ThrowOnConvert = new InvalidOperationException("FreeSpire kaputt");

        var act = () => CreateService().ConvertDocxToPdfAsync("egal.docx");

        await act.Should().ThrowAsync<PdfConversionUnavailableException>();
    }

    [Fact]
    public async Task PropagatesFileNotFound_WithoutFallback()
    {
        _wordConverter.ThrowOnConvert = new FileNotFoundException("weg");

        var act = () => CreateService().ConvertDocxToPdfAsync("egal.docx");

        await act.Should().ThrowAsync<FileNotFoundException>();
        _freeSpireConverter.ConvertCalls.Should().Be(0);
    }
}
