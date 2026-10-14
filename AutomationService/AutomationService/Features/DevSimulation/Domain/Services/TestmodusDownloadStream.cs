namespace AutomationService.Features.DevSimulation.Domain.Services;

/// <summary>
/// Der Download-Strom der <see cref="TestmodusAktualisierungsQuelle"/>: liefert
/// höchstens 64 KiB je Lesevorgang und wartet davor eine feste Zeit — wie eine
/// langsame Leitung, nur ohne Leitung. Die Wartezeit hört auf den
/// Abbruch, damit „Abbrechen" auch im Testmodus sofort greift.
/// </summary>
public sealed class TestmodusDownloadStream(byte[] daten, TimeSpan verzoegerungJeBlock) : Stream
{
    private const int Blockgroesse = 64 * 1024;
    private int _position;

    public override bool CanRead => true;

    public override bool CanSeek => false;

    public override bool CanWrite => false;

    public override long Length => daten.Length;

    public override long Position
    {
        get => _position;
        set => throw new NotSupportedException();
    }

    public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default)
    {
        if (verzoegerungJeBlock > TimeSpan.Zero)
        {
            await Task.Delay(verzoegerungJeBlock, cancellationToken);
        }

        return Read(buffer.Span);
    }

    public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken) =>
        ReadAsync(buffer.AsMemory(offset, count), cancellationToken).AsTask();

    public override int Read(byte[] buffer, int offset, int count) => Read(buffer.AsSpan(offset, count));

    public override int Read(Span<byte> buffer)
    {
        var anzahl = Math.Min(Math.Min(buffer.Length, Blockgroesse), daten.Length - _position);
        daten.AsSpan(_position, anzahl).CopyTo(buffer);
        _position += anzahl;
        return anzahl;
    }

    public override void Flush()
    {
    }

    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();

    public override void SetLength(long value) => throw new NotSupportedException();

    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}
