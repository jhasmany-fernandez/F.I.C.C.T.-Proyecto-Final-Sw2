/** Llamadas a la API de proyectos para el admin. Sprint 1 — PB-18. */

import { apiClient } from "@/shared/api/client";
import type {
  APRecommendationParams,
  APRecommendationResult,
  CoverageAnalysis,
  CoverageAnalysisParams,
  ProyectoListOut,
  ProyectoReasignarIn,
  ProyectosFilter,
  ProyectosPageOut,
  TechnicalReportDownload,
  TechnicalReportParams,
} from "../types";

export async function listarProyectosOrg(
  page = 1,
  pageSize = 20,
  filtros?: ProyectosFilter,
): Promise<ProyectosPageOut> {
  const { data } = await apiClient.get<ProyectosPageOut>("/admin/proyectos", {
    params: {
      page,
      page_size: pageSize,
      ...filtros,
    },
  });
  return data;
}

export async function archivarProyectoAdmin(
  id: number,
): Promise<ProyectoListOut> {
  const { data } = await apiClient.patch<ProyectoListOut>(
    `/admin/proyectos/${id}/archivar`,
  );
  return data;
}

export async function reasignarTecnico(
  id: number,
  body: ProyectoReasignarIn,
): Promise<ProyectoListOut> {
  const { data } = await apiClient.patch<ProyectoListOut>(
    `/admin/proyectos/${id}/reasignar`,
    body,
  );
  return data;
}

export async function getCoverageAnalysis(
  projectId: number,
  params: CoverageAnalysisParams,
): Promise<CoverageAnalysis> {
  const { data } = await apiClient.get<CoverageAnalysis>(
    `/proyectos/${projectId}/coverage-analysis`,
    {
      params: {
        plano_id: params.plano_id,
        ssid: params.ssid || undefined,
        bssid: params.bssid || undefined,
        metric: params.metric ?? "best_rssi",
        include_heatmap_summary: params.include_heatmap_summary ?? true,
      },
    },
  );
  return data;
}

export async function generateAPRecommendations(
  projectId: number,
  body: APRecommendationParams,
): Promise<APRecommendationResult> {
  const { data } = await apiClient.post<APRecommendationResult>(
    `/proyectos/${projectId}/ap-recommendations`,
    body,
  );
  return data;
}

export async function exportTechnicalReport(
  projectId: number,
  body: TechnicalReportParams,
): Promise<TechnicalReportDownload> {
  try {
    const response = await apiClient.post<Blob>(
      `/proyectos/${projectId}/technical-report`,
      body,
      {
        responseType: "blob",
      },
    );

    const rawContentType = response.headers["content-type"];
    const contentType =
      typeof rawContentType === "string" ? rawContentType : "";
    if (!contentType.toLowerCase().includes("application/pdf")) {
      throw new Error("El backend no devolvió un PDF válido.");
    }

    return {
      blob: response.data,
      filename: extractFilename(
        typeof response.headers["content-disposition"] === "string"
          ? response.headers["content-disposition"]
          : undefined,
        projectId,
      ),
      contentType,
    };
  } catch (error) {
    await normalizeBlobAxiosError(error);
    throw error;
  }
}

function extractFilename(
  contentDisposition: string | undefined,
  projectId: number,
): string {
  const fallback = `wireless-heatmapper-proyecto-${projectId}.pdf`;
  if (!contentDisposition) {
    return fallback;
  }

  const utf8Match = contentDisposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (utf8Match?.[1]) {
    return decodeURIComponent(utf8Match[1]);
  }

  const plainMatch = contentDisposition.match(/filename="?([^"]+)"?/i);
  return plainMatch?.[1] ?? fallback;
}

async function normalizeBlobAxiosError(error: unknown) {
  if (
    typeof error !== "object" ||
    error === null ||
    !("isAxiosError" in error) ||
    !(error as { isAxiosError?: boolean }).isAxiosError
  ) {
    return;
  }

  const response = (error as { response?: { data?: unknown } }).response;
  if (!(response?.data instanceof Blob)) {
    return;
  }

  const text = await response.data.text();
  try {
    response.data = JSON.parse(text) as unknown;
  } catch {
    response.data = { detail: text };
  }
}
