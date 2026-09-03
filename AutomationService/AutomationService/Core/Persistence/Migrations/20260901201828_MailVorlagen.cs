using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class MailVorlagen : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "MailVorlagen",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Name = table.Column<string>(type: "TEXT", maxLength: 128, nullable: false),
                    Betreff = table.Column<string>(type: "TEXT", maxLength: 512, nullable: false),
                    Text = table.Column<string>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MailVorlagen", x => x.Id);
                });

            migrationBuilder.InsertData(
                table: "MailVorlagen",
                columns: new[] { "Id", "Betreff", "Name", "Text" },
                values: new object[] { 1, "Ihre Verkehrsunfallsache {{MandantName}} ./. {{VersichererName}} · Unser Zeichen: {{Referenz}}", "Anschreiben an den Mandanten", "{{Anrede}},\n{{Zusatzgruß}},\n\nich bedanke mich höflichst für das mir entgegengebrachte Vertrauen und die Übertragung des Mandats in vorbezeichneter Angelegenheit.\n\nIn der Anlage überlasse ich Ihnen zur Kenntnisnahme meinen Schriftsatz an die gegnerische Haftpflichtversicherung, welche ich unter Fristsetzung aufgefordert habe, ihre Haftung dem Grunde nach anzuerkennen und Schadensersatz nach Gutachten zu leisten. Die Einzelheiten möchten Sie bitte meinem Schriftsatz entnehmen.\n\nNunmehr bleibt die Stellungnahme der gegnerischen Haftpflichtversicherung abzuwarten. Sobald mir das Gutachten vorliegt, werde ich den Schadensersatzanspruch beziffern.\n\nFür Rückfragen stehe ich Ihnen gerne zur Verfügung. Sobald mir neue Informationen vorliegen, werde ich selbstverständlich wieder berichten.\n\nMit freundlichen Grüßen" });

            migrationBuilder.CreateIndex(
                name: "IX_MailVorlagen_Name",
                table: "MailVorlagen",
                column: "Name",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MailVorlagen");
        }
    }
}
