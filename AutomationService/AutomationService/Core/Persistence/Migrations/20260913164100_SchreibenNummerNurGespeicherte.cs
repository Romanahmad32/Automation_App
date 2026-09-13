using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <summary>
    /// Hebt den Bestand auf die neue Bedeutung von
    /// <c>Vorgaenge.SchreibenNummer</c>: „Nummer des zuletzt <b>gespeicherten</b>
    /// Schreibens" statt „des zuletzt erzeugten" (#133, §4.9).
    /// </summary>
    /// <remarks>
    /// Bis hierher setzte das Frontend die Nummer schon beim <em>Erzeugen</em>
    /// eines Dokuments. Deshalb tragen Vorgänge eine Nummer, zu denen nie ein
    /// Schreiben abgelegt wurde — und die Leiste über dem Ausfüllformular fragte
    /// dort „Korrektur oder neues Schreiben?" zu einer Arbeitskopie, die die
    /// nächste Ablage ohnehin wegräumt. Diese Nummern werden auf NULL gesetzt;
    /// wo etwas gespeichert wurde, bleibt sie stehen.
    ///
    /// <b>Die Grenze ist der Status <c>abgelegt</c></b>, der erste, den ein
    /// Speicherschritt erzeugt (<c>VorgangStatus</c>: angefragt → beantwortet →
    /// erstellt → abgelegt → versendet). Alles darunter — <c>angefragt</c>,
    /// <c>beantwortet</c>, <c>erstellt</c> — hat den Speicherschritt nie
    /// durchlaufen: <c>erstellt</c> heisst genau „erzeugt, nicht abgelegt".
    /// Das freie „an anderem Ort speichern" belegt die Nummer zwar künftig
    /// ebenfalls, ändert aber den Status nicht; im Bestand kann es keinen
    /// solchen Fall geben, weil dieser Weg die Nummer bisher gar nicht anfasste.
    ///
    /// Aufgezählt statt verglichen: SQLite kennt die Reihenfolge des Enums
    /// nicht, <c>Status &lt; 'abgelegt'</c> wäre ein alphabetischer Vergleich
    /// und träfe genau die falschen Zeilen. Ein unbekannter Statuswert bleibt so
    /// unberührt — nichts wird gelöscht, was niemand zuordnen kann.
    ///
    /// <c>Down</c> ist leer: Die weggenommenen Nummern liessen sich nicht
    /// zurückholen, und sie wiederherzustellen hiesse, die alte Fehldeutung
    /// wiederherzustellen.
    /// </remarks>
    public partial class SchreibenNummerNurGespeicherte : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(
                """
                UPDATE Vorgaenge
                SET SchreibenNummer = NULL
                WHERE SchreibenNummer IS NOT NULL
                  AND Status IN ('angefragt', 'beantwortet', 'erstellt');
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Absichtlich leer — siehe Klassenkommentar.
        }
    }
}
