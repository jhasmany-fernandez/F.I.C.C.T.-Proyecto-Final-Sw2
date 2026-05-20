import { useMutation } from "@tanstack/react-query";
import { generateAPRecommendations } from "../api/proyectosApi";
import type { APRecommendationParams } from "../types";

export function useApRecommendations(projectId: number) {
  return useMutation({
    mutationFn: (body: APRecommendationParams) =>
      generateAPRecommendations(projectId, body),
  });
}
