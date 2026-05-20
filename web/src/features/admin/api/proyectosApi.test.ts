import { describe, expect, it, vi, beforeEach } from "vitest";
import {
  exportTechnicalReport,
  generateAPRecommendations,
  getCoverageAnalysis,
} from "./proyectosApi";
import { apiClient } from "@/shared/api/client";

vi.mock("@/shared/api/client", () => ({
  apiClient: {
    get: vi.fn(),
    post: vi.fn(),
  },
}));

describe("getCoverageAnalysis", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("llama al endpoint correcto con params esperados", async () => {
    vi.mocked(apiClient.get).mockResolvedValue({
      data: { proyecto_id: 3 },
    } as never);

    await getCoverageAnalysis(3, {
      plano_id: 2,
      ssid: "Bulldog-5G",
      bssid: "AA:BB:CC:DD:EE:FF",
      metric: "avg_rssi",
      include_heatmap_summary: true,
    });

    expect(apiClient.get).toHaveBeenCalledWith(
      "/proyectos/3/coverage-analysis",
      {
        params: {
          plano_id: 2,
          ssid: "Bulldog-5G",
          bssid: "AA:BB:CC:DD:EE:FF",
          metric: "avg_rssi",
          include_heatmap_summary: true,
        },
      },
    );
  });

  it("envía recomendaciones al endpoint correcto", async () => {
    vi.mocked(apiClient.post).mockResolvedValue({
      data: { proyecto_id: 3 },
    } as never);

    await generateAPRecommendations(3, {
      plano_id: 2,
      target_rssi_dbm: -70,
      max_recommendations: 3,
      strategy: "coverage_gap",
      band_preference: "auto",
      include_channel_plan: true,
    });

    expect(apiClient.post).toHaveBeenCalledWith(
      "/proyectos/3/ap-recommendations",
      {
        plano_id: 2,
        target_rssi_dbm: -70,
        max_recommendations: 3,
        strategy: "coverage_gap",
        band_preference: "auto",
        include_channel_plan: true,
      },
    );
  });

  it("descarga el reporte técnico como blob y lee el filename", async () => {
    const pdfBlob = new Blob(["%PDF-demo"], { type: "application/pdf" });
    vi.mocked(apiClient.post).mockResolvedValue({
      data: pdfBlob,
      headers: {
        "content-type": "application/pdf",
        "content-disposition":
          'attachment; filename="wireless-heatmapper-proyecto-3.pdf"',
      },
    } as never);

    const result = await exportTechnicalReport(3, {
      plano_id: 2,
      include_heatmap: true,
      include_coverage_analysis: true,
      include_ap_recommendations: true,
      metric: "best_rssi",
      target_rssi_dbm: -70,
      format: "pdf",
    });

    expect(apiClient.post).toHaveBeenCalledWith(
      "/proyectos/3/technical-report",
      {
        plano_id: 2,
        include_heatmap: true,
        include_coverage_analysis: true,
        include_ap_recommendations: true,
        metric: "best_rssi",
        target_rssi_dbm: -70,
        format: "pdf",
      },
      {
        responseType: "blob",
      },
    );
    expect(result.blob).toBe(pdfBlob);
    expect(result.filename).toBe("wireless-heatmapper-proyecto-3.pdf");
    expect(result.contentType).toBe("application/pdf");
  });

  it("falla si la respuesta no es un pdf", async () => {
    vi.mocked(apiClient.post).mockResolvedValue({
      data: new Blob(["not pdf"], { type: "text/plain" }),
      headers: {
        "content-type": "text/plain",
      },
    } as never);

    await expect(
      exportTechnicalReport(3, {
        plano_id: 2,
        include_heatmap: true,
        include_coverage_analysis: true,
        include_ap_recommendations: true,
        metric: "best_rssi",
        target_rssi_dbm: -70,
        format: "pdf",
      }),
    ).rejects.toThrow("El backend no devolvió un PDF válido.");
  });
});
