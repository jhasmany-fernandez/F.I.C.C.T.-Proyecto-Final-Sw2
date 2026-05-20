import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { AxiosError } from "axios";
import type { ReactNode } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import CoverageAnalysisPage from "./CoverageAnalysisPage";
import type {
  APRecommendationResult,
  CoverageAnalysis,
  TechnicalReportDownload,
} from "../types";

const mockToast = {
  exito: vi.fn(),
  error: vi.fn(),
  info: vi.fn(),
};

const mockUseParams = vi.fn();
const mockUseCoverageAnalysis = vi.fn();
const mockUseApRecommendations = vi.fn();
const mockUseTechnicalReport = vi.fn();

vi.mock("react-router-dom", () => ({
  Link: ({ to, children }: { to: string; children: ReactNode }) => (
    <a href={to}>{children}</a>
  ),
  useParams: () => mockUseParams(),
}));

vi.mock("@/shared/components", async () => {
  const actual = await vi.importActual<typeof import("@/shared/components")>(
    "@/shared/components",
  );
  return {
    ...actual,
    useToast: () => mockToast,
  };
});

vi.mock("../hooks/useCoverageAnalysis", () => ({
  useCoverageAnalysis: (...args: unknown[]) => mockUseCoverageAnalysis(...args),
}));

vi.mock("../hooks/useApRecommendations", () => ({
  useApRecommendations: (...args: unknown[]) => mockUseApRecommendations(...args),
}));

vi.mock("../hooks/useTechnicalReport", () => ({
  useTechnicalReport: (...args: unknown[]) => mockUseTechnicalReport(...args),
}));

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

function buildRecommendations(): APRecommendationResult {
  return {
    proyecto_id: 3,
    plano_id: 2,
    generated_at: "2026-05-19T16:24:09.140476Z",
    target_rssi_dbm: -70,
    strategy: "coverage_gap",
    recommendations: [],
    assumptions: [],
    warnings: [],
  };
}

describe("CoverageAnalysisPage technical report export", () => {
  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
  });

  beforeEach(() => {
    vi.clearAllMocks();
    mockUseParams.mockReturnValue({ proyectoId: "3" });
    mockUseCoverageAnalysis.mockReturnValue({
      isLoading: false,
      isFetching: false,
      isError: false,
      data: buildAnalysis(),
      refetch: vi.fn(),
    });
    mockUseApRecommendations.mockReturnValue({
      isPending: false,
      data: buildRecommendations(),
      error: null,
      reset: vi.fn(),
      mutate: vi.fn(),
    });
    mockUseTechnicalReport.mockReturnValue({
      isPending: false,
      isSuccess: false,
      isError: false,
      error: null,
      mutateAsync: vi.fn(),
    });
    mockToast.exito.mockReset();
    mockToast.error.mockReset();
    mockToast.info.mockReset();
  });

  it("renderiza el botón de exportación", () => {
    render(<CoverageAnalysisPage />);

    expect(
      screen.getByRole("button", { name: "Exportar reporte PDF" }),
    ).toBeInTheDocument();
  });

  it("descarga el pdf correctamente cuando el backend responde un blob", async () => {
    const createObjectURL = vi.fn(() => "blob:demo");
    const revokeObjectURL = vi.fn();
    const click = vi.fn();
    const appendChild = vi.spyOn(document.body, "appendChild");
    const originalCreateElement = document.createElement.bind(document);

    vi.stubGlobal("URL", {
      createObjectURL,
      revokeObjectURL,
    });

    vi.spyOn(document, "createElement").mockImplementation(((tagName: string) => {
      const element = originalCreateElement(tagName);
      if (tagName === "a") {
        Object.defineProperty(element, "click", {
          value: click,
        });
      }
      return element;
    }) as typeof document.createElement);

    const mutateAsync = vi.fn<() => Promise<TechnicalReportDownload>>(
      async () => ({
        blob: new Blob(["%PDF-demo"], { type: "application/pdf" }),
        filename: "wireless-heatmapper-proyecto-3.pdf",
        contentType: "application/pdf",
      }),
    );

    mockUseTechnicalReport.mockReturnValue({
      isPending: false,
      isSuccess: false,
      isError: false,
      error: null,
      mutateAsync,
    });

    render(<CoverageAnalysisPage />);

    fireEvent.click(screen.getByRole("button", { name: "Exportar reporte PDF" }));

    await waitFor(() => {
      expect(mutateAsync).toHaveBeenCalledWith({
        plano_id: 2,
        include_heatmap: true,
        include_coverage_analysis: true,
        include_ap_recommendations: true,
        metric: "best_rssi",
        target_rssi_dbm: -70,
        format: "pdf",
      });
    });

    expect(createObjectURL).toHaveBeenCalled();
    expect(click).toHaveBeenCalled();
    expect(revokeObjectURL).toHaveBeenCalledWith("blob:demo");
    expect(appendChild).toHaveBeenCalled();
    expect(mockToast.exito).toHaveBeenCalledWith(
      "Reporte descargado correctamente",
    );
  });

  it("muestra error controlado cuando el reporte falla con 409", () => {
    const error = new AxiosError(
      "Conflict",
      "ERR_BAD_REQUEST",
      undefined,
      undefined,
      {
        status: 409,
        statusText: "Conflict",
        headers: {},
        config: { headers: {} } as never,
        data: { detail: "El proyecto debe tener un plano cargado." },
      },
    );

    mockUseTechnicalReport.mockReturnValue({
      isPending: false,
      isSuccess: false,
      isError: true,
      error,
      mutateAsync: vi.fn(),
    });

    render(<CoverageAnalysisPage />);

    expect(
      screen.getByText("El proyecto debe tener un plano cargado."),
    ).toBeInTheDocument();
  });

  it("muestra error si la respuesta del backend no es pdf", () => {
    mockUseTechnicalReport.mockReturnValue({
      isPending: false,
      isSuccess: false,
      isError: true,
      error: new Error("El backend no devolvió un PDF válido."),
      mutateAsync: vi.fn(),
    });

    render(<CoverageAnalysisPage />);

    expect(
      screen.getByText("La respuesta del backend no es un PDF válido."),
    ).toBeInTheDocument();
  });
});
