import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import APRecommendationsPanel from "./APRecommendationsPanel";
import type { APRecommendationResult } from "../types";

function buildResult(
  overrides: Partial<APRecommendationResult> = {},
): APRecommendationResult {
  return {
    proyecto_id: 3,
    plano_id: 2,
    generated_at: "2026-05-19T16:24:09.140476Z",
    target_rssi_dbm: -70,
    strategy: "coverage_gap",
    recommendations: [],
    assumptions: [
      "No se modelaron paredes por material en esta versión.",
      "La potencia sugerida se mantiene entre 1/4 y 1/3 del máximo.",
    ],
    warnings: ["La cobertura cumple el objetivo definido."],
    ...overrides,
  };
}

describe("APRecommendationsPanel", () => {
  it("muestra estado vacío inicial", () => {
    render(
      <APRecommendationsPanel result={null} isLoading={false} errorMessage={null} />,
    );

    expect(
      screen.getByText(
        "Genera recomendaciones desde esta pantalla para evaluar posiciones óptimas de AP.",
      ),
    ).toBeInTheDocument();
  });

  it("muestra warning cuando no se requieren nuevos APs", () => {
    render(
      <APRecommendationsPanel
        result={buildResult()}
        isLoading={false}
        errorMessage={null}
      />,
    );

    expect(
      screen.getByText("La cobertura cumple el objetivo definido."),
    ).toBeInTheDocument();
    expect(
      screen.getByText("No se requieren nuevos APs con el objetivo actual."),
    ).toBeInTheDocument();
  });

  it("muestra recomendaciones cuando existen", () => {
    render(
      <APRecommendationsPanel
        result={buildResult({
          warnings: [],
          recommendations: [
            {
              id: "ap-rec-1",
              x: 0.35,
              y: 0.62,
              band: "5GHz",
              channel: 36,
              tx_power: "medium",
              tx_power_fraction: 0.25,
              expected_rssi_dbm: -66,
              confidence: 0.78,
              reason:
                "Cubre zona débil cercana y reduce solapamiento con APs detectados.",
              covers_findings: ["weak_zone", "overlap"],
              warnings: [],
            },
          ],
        })}
        isLoading={false}
        errorMessage={null}
      />,
    );

    expect(screen.getByText("ap-rec-1")).toBeInTheDocument();
    expect(screen.getByText("Confianza 78%")).toBeInTheDocument();
    expect(screen.getByText(/5GHz \/ 36/)).toBeInTheDocument();
    expect(screen.getByText(/weak_zone, overlap/)).toBeInTheDocument();
  });
});
