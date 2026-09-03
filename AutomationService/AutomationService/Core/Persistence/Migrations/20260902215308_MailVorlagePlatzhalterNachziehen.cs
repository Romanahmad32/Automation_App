using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <summary>
    /// Zieht den umbenannten Platzhalter in vorhandenen Mailvorlagen nach:
    /// <c>{{Grussformel}}</c> heißt seit dem 02.09.2026 <c>{{Zusatzgruß}}</c>.
    /// </summary>
    /// <remarks>
    /// Nötig, weil die Umbenennung zuerst nur im Seed der Migration
    /// <c>20260901201828_MailVorlagen</c> stand — nachträglich, an Ort und
    /// Stelle. Frische Datenbanken bekommen den neuen Namen damit; jede, die
    /// diese Migration schon gefahren hatte, behielt den alten und damit einen
    /// Platzhalter, den <c>MailPlatzhalter</c> nicht mehr kennt: Die Grußzeile
    /// fiel aus dem Text, und der Vorlageneditor meldete „kein Feld dieses
    /// Namens".
    ///
    /// <c>UPDATE … REPLACE</c> und nicht <c>UpdateData</c>: Das ersetzt genau
    /// den Platzhalter, in jeder Vorlage, und lässt den übrigen Text stehen —
    /// auch den, den der Anwalt selbst geschrieben hat. Ein <c>UpdateData</c>
    /// auf Zeile 1 würde dessen Änderungen verwerfen.
    /// </remarks>
    public partial class MailVorlagePlatzhalterNachziehen : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE MailVorlagen
                SET Text = REPLACE(Text, '{{Grussformel}}', '{{Zusatzgruß}}')
                WHERE Text LIKE '%{{Grussformel}}%';
                """);

            // Der Betreff trug ihn nie ab Werk — aber eintragen konnte man ihn
            // dort, und dann steht dieselbe Leiche in derselben Vorlage.
            migrationBuilder.Sql(
                """
                UPDATE MailVorlagen
                SET Betreff = REPLACE(Betreff, '{{Grussformel}}', '{{Zusatzgruß}}')
                WHERE Betreff LIKE '%{{Grussformel}}%';
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE MailVorlagen
                SET Text = REPLACE(Text, '{{Zusatzgruß}}', '{{Grussformel}}')
                WHERE Text LIKE '%{{Zusatzgruß}}%';
                """);

            migrationBuilder.Sql(
                """
                UPDATE MailVorlagen
                SET Betreff = REPLACE(Betreff, '{{Zusatzgruß}}', '{{Grussformel}}')
                WHERE Betreff LIKE '%{{Zusatzgruß}}%';
                """);
        }
    }
}
