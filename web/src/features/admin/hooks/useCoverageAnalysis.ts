import { useQuery } from "@tanstack/react-query";
import { getCoverageAnalysis } from "../api/proyectosApi";
import type { CoverageAnalysisParams } from "../types";

export function useCoverageAnalysis(
  projectId: number,
  params: CoverageAnalysisParams,
) {
  return useQuery({
    queryKey: ["admin", "coverage-analysis", projectId, params],
    queryFn: () => getCoverageAnalysis(projectId, params),
    enabled: Number.isFinite(projectId) && projectId > 0,
  });
}
