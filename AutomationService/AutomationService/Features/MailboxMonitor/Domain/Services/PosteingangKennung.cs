using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.WebUtilities;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

// UIDs gelten nur innerhalb eines Kontos, Ordners und einer UIDVALIDITY.
// Auch nach einem Kontowechsel darf ein alter Klick keine andere Mail öffnen.
public sealed record PosteingangKennung(string Konto, uint Gueltigkeit, uint Uid)
{
    public static string KontoFuer(MailboxOptions options) => Convert.ToHexString(SHA256.HashData(
        Encoding.UTF8.GetBytes($"{options.Host.ToLowerInvariant()}\n{options.Port}\n{options.Username.ToLowerInvariant()}\n{options.Folder}")));

    public string Encode() => WebEncoders.Base64UrlEncode(JsonSerializer.SerializeToUtf8Bytes(this));

    public static PosteingangKennung Decode(string wert, string konto, uint gueltigkeit)
    {
        try
        {
            if (wert.Length > 512)
            {
                throw new FormatException();
            }
            var kennung = JsonSerializer.Deserialize<PosteingangKennung>(WebEncoders.Base64UrlDecode(wert));
            if (kennung is null || kennung.Uid == 0 || kennung.Konto != konto || kennung.Gueltigkeit != gueltigkeit)
            {
                throw new PosteingangException("Das Postfach hat sich geändert. Bitte den Posteingang aktualisieren.");
            }
            return kennung;
        }
        catch (Exception ex) when (ex is FormatException or JsonException)
        {
            throw new PosteingangException("Ungültige Nachrichtenkennung. Bitte den Posteingang aktualisieren.", 400);
        }
    }
}
