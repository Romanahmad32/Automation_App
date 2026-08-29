using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace AutomationService.Core.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class Versandprotokoll : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Versandprotokoll",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    VorgangReferenz = table.Column<string>(type: "TEXT", nullable: false),
                    GesendetAm = table.Column<DateTime>(type: "TEXT", nullable: false),
                    Weg = table.Column<string>(type: "TEXT", nullable: false),
                    Absender = table.Column<string>(type: "TEXT", nullable: false),
                    EmpfaengerJson = table.Column<string>(type: "TEXT", nullable: false),
                    KopieJson = table.Column<string>(type: "TEXT", nullable: false),
                    Betreff = table.Column<string>(type: "TEXT", nullable: false),
                    AnhaengeJson = table.Column<string>(type: "TEXT", nullable: false),
                    ImGesendetOrdner = table.Column<bool>(type: "INTEGER", nullable: false),
                    MessageId = table.Column<string>(type: "TEXT", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Versandprotokoll", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Versandprotokoll_VorgangReferenz",
                table: "Versandprotokoll",
                column: "VorgangReferenz");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Versandprotokoll");
        }
    }
}
