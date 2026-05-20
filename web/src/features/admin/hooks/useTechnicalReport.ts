import { useMutation } from "@tanstack/react-query";
import { exportTechnicalReport } from "../api/proyectosApi";
import type { TechnicalReportParams } from "../types";

export function useTechnicalReport(projectId: number) {
  return useMutation({
    mutationFn: (body: TechnicalReportParams) =>
      exportTechnicalReport(projectId, body),
  });
}
