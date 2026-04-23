import request from "supertest";
import { describe, expect, it } from "vitest";

import {
  createApp,
  createApplicationServices,
  type ApplicationServices,
} from "../src/app.js";

describe("reports phase 6", () => {
  it("returns daily, weekly and monthly summaries with ranking data", async () => {
    const services = createApplicationServices();
    seedReportData(services);
    const seededApp = createApp(services);

    const loginResponse = await request(seededApp)
      .post("/api/auth/login")
      .send({
        email: "manager@tatuzin.app",
        password: "tatuzin123",
      });
    const seededAccessToken = loginResponse.body.tokens.accessToken as string;

    const response = await request(seededApp)
      .get("/api/reports/dashboard")
      .query({
        referenceDate: "2026-04-21T18:00:00.000Z",
        rankingLimit: 3,
      })
      .set("Authorization", `Bearer ${seededAccessToken}`);

    expect(response.status).toBe(200);
    expect(response.body.reports.daily.salesCount).toBe(1);
    expect(response.body.reports.daily.netRevenueInCents).toBe(15900);
    expect(response.body.reports.daily.liquidatedRevenueInCents).toBe(15900);
    expect(response.body.reports.daily.noteRevenueInCents).toBe(0);
    expect(response.body.reports.weekly.salesCount).toBe(2);
    expect(response.body.reports.monthly.salesCount).toBe(3);
    expect(response.body.reports.daily.topProducts[0].label).toBe(
      "Bolsa Tiracolo",
    );
    expect(response.body.reports.daily.topVariants[0].label).toContain(
      "Bolsa Tiracolo",
    );
    expect(
      response.body.reports.daily.paymentBreakdown.find(
        (item: { method: string }) => item.method === "cash",
      )?.amountInCents,
    ).toBe(15900);
    expect(response.body.reports.daily.openReceivablesCount).toBe(1);
    expect(response.body.reports.daily.overdueReceivablesCount).toBe(0);
  });

  it("blocks seller access to administrative reports", async () => {
    const services = createApplicationServices();
    const app = createApp(services);
    const loginResponse = await request(app).post("/api/auth/login").send({
      email: "seller@tatuzin.app",
      password: "tatuzin123",
    });

    const response = await request(app)
      .get("/api/reports/dashboard")
      .set(
        "Authorization",
        `Bearer ${loginResponse.body.tokens.accessToken as string}`,
      );

    expect(response.status).toBe(403);
  });
});

function seedReportData(services: ApplicationServices): void {
  const customer = services.crmService.createCustomer({
    companyId: "company_tatuzin",
    name: "Maria Relatorios",
    phone: "11999990001",
  });

  services.salesService.createSale({
    companyId: "company_tatuzin",
    userId: "user_manager",
    customerId: customer.id,
    subtotalInCents: 15900,
    discountInCents: 0,
    totalInCents: 15900,
    createdAt: "2026-04-21T10:00:00.000Z",
    items: [
      {
        variantId: "var_bolsa_tiracolo_preta_u",
        displayName: "Bolsa Tiracolo Preta U",
        quantity: 1,
        unitPriceInCents: 15900,
        totalPriceInCents: 15900,
      },
    ],
    payments: [{ method: "cash", amountInCents: 15900 }],
  });

  services.salesService.createSale({
    companyId: "company_tatuzin",
    userId: "user_manager",
    customerId: customer.id,
    subtotalInCents: 9900,
    discountInCents: 0,
    totalInCents: 9900,
    createdAt: "2026-04-20T14:00:00.000Z",
    items: [
      {
        variantId: "var_camiseta_oversized_preta_m",
        displayName: "Camiseta Oversized Preta M",
        quantity: 1,
        unitPriceInCents: 9900,
        totalPriceInCents: 9900,
      },
    ],
    payments: [
      {
        method: "note",
        amountInCents: 9900,
        dueDate: "2026-04-30T00:00:00.000Z",
        notes: "Prazo da cliente VIP",
      },
    ],
  });

  services.salesService.createSale({
    companyId: "company_tatuzin",
    userId: "user_manager",
    subtotalInCents: 12900,
    discountInCents: 1000,
    totalInCents: 11900,
    createdAt: "2026-04-05T09:30:00.000Z",
    items: [
      {
        variantId: "var_bolsa_tiracolo_preta_u",
        displayName: "Bolsa Tiracolo Preta U",
        quantity: 1,
        unitPriceInCents: 12900,
        totalPriceInCents: 12900,
      },
    ],
    payments: [{ method: "pix", amountInCents: 11900 }],
  });
}
