import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import CoverageAnalysisPanel from "./CoverageAnalysisPanel";
import type { CoverageAnalysis } from "../types";

function buildAnalysis(
  overrides: Partial<CoverageAnalysis> = {},
): CoverageAnalysis {
  return {
    proyecto_id: 3,
    plano_id: 2,
    generated_at: "2026-05-19T15:22:33.028364Z",
    objective_rssi_dbm: -70,
    dead_zone_threshold_dbm: -90,
    metric: "best_rssi",
    summary: {
      points_analyzed: 1,
      dead_zones_count: 0,
      weak_zones_count: 0,
      coverage_ok_count: 1,
      coverage_ok_percent: 100,
      avg_rssi_dbm: -61,
      best_rssi_dbm: -61,
      worst_rssi_dbm: -61,
    },
    findings: [],
    channel_analysis: {
      cci: [],
      aci: [],
    },
    heatmap_summary: {
      metric: "best_rssi",
      min_rssi: -90,
      max_rssi: -35,
      points_used: 1,
      warning: "Heatmap aproximado: menos de 3 puntos disponibles.",
    },
    ...overrides,
  };
}

describe("CoverageAnalysisPanel", () => {
  it("muestra estado vacío cuando no hay findings", () => {
    render(<CoverageAnalysisPanel analysis={buildAnalysis()} />);

    expect(
      screen.getByText("No se detectaron problemas críticos."),
    ).toBeInTheDocument();
    expect(
      screen.getByText("No se detectaron conflictos de canal."),
    ).toBeInTheDocument();
  });

  it("muestra findings y análisis de canal cuando existen", () => {
    render(
      <CoverageAnalysisPanel
        analysis={buildAnalysis({
          findings: [
            {
              type: "dead_zone",
              severity: "critical",
              message: "Zona muerta detectada: RSSI menor a -90 dBm.",
              punto_id: 7,
              x: 0.25,
              y: 0.7,
              rssi_dbm: -94,
              recommendation: "Agregar o reubicar un AP cercano.",
            },
          ],
          channel_analysis: {
            cci: [
              {
                channel: 6,
                frequency_mhz: 2437,
                severity: "medium",
                bssid_count: 3,
                bssids: ["AA:BB:CC:DD:EE:FF"],
                recommendation: "Reducir APs en el mismo canal o cambiar canal.",
              },
            ],
            aci: [
              {
                channel: 5,
                adjacent_to: 6,
                severity: "low",
                recommendation: "Revisar planificación de canales.",
              },
            ],
          },
        })}
      />,
    );

    expect(screen.getByText("Zona muerta")).toBeInTheDocument();
    expect(screen.getByText(/Punto #7/)).toBeInTheDocument();
    expect(screen.getByText("CCI en canal 6")).toBeInTheDocument();
    expect(screen.getByText("ACI entre canales 5 y 6")).toBeInTheDocument();
  });

  it("muestra warning del heatmap como aviso", () => {
    render(<CoverageAnalysisPanel analysis={buildAnalysis()} />);

    expect(
      screen.getByText("Heatmap aproximado: menos de 3 puntos disponibles."),
    ).toBeInTheDocument();
  });
});
