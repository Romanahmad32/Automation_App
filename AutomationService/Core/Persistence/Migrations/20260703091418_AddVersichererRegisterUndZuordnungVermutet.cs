using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddVersichererRegisterUndZuordnungVermutet : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "ZuordnungVermutet",
                table: "ReceivedReplies",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "Versicherer",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    Name = table.Column<string>(type: "TEXT", nullable: false),
                    NameNormalisiert = table.Column<string>(type: "TEXT", nullable: false),
                    Strasse = table.Column<string>(type: "TEXT", nullable: true),
                    Plz = table.Column<string>(type: "TEXT", nullable: true),
                    Ort = table.Column<string>(type: "TEXT", nullable: true),
                    Telefon = table.Column<string>(type: "TEXT", nullable: true),
                    Fax = table.Column<string>(type: "TEXT", nullable: true),
                    Email = table.Column<string>(type: "TEXT", nullable: true),
                    ZuletztAktualisiertAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Quelle = table.Column<string>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Versicherer", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Versicherer_NameNormalisiert",
                table: "Versicherer",
                column: "NameNormalisiert",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Versicherer");

            migrationBuilder.DropColumn(
                name: "ZuordnungVermutet",
                table: "ReceivedReplies");
        }
    }
}
