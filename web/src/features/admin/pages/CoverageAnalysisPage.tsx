import { useMemo, useState } from "react";
import { AxiosError } from "axios";
import { ArrowLeft, RefreshCw } from "lucide-react";
import { Link, useParams } from "react-router-dom";
import { Button, EmptyState, useToast } from "@/shared/components";
import APRecommendationsPanel from "../components/APRecommendationsPanel";
import CoverageAnalysisPanel from "../components/CoverageAnalysisPanel";
import { useApRecommendations } from "../hooks/useApRecommendations";
import { useCoverageAnalysis } from "../hooks/useCoverageAnalysis";
import { useTechnicalReport } from "../hooks/useTechnicalReport";
import type { CoverageMetric, RecommendationBand } from "../types";
import styles from "./CoverageAnalysisPage.module.css";

type BackendError = {
  detail?: string;
};

export default function CoverageAnalysisPage() {
  const { proyectoId } = useParams<{ proyectoId: string }>();
  const projectId = Number(proyectoId);

  const [planoIdInput, setPlanoIdInput] = useState("");
  const [ssidInput, setSsidInput] = useState("");
  const [bssidInput, setBssidInput] = useState("");
  const [metric, setMetric] = useState<CoverageMetric>("best_rssi");
  const [includeHeatmapSummary, setIncludeHeatmapSummary] = useState(true);
  const [submittedPlanoId, setSubmittedPlanoId] = useState<number | undefined>(
    undefined,
  );
  const [submittedSsid, setSubmittedSsid] = useState("");
  const [submittedBssid, setSubmittedBssid] = useState("");
  const [submittedMetric, setSubmittedMetric] =
    useState<CoverageMetric>("best_rssi");
  const [submittedIncludeHeatmapSummary, setSubmittedIncludeHeatmapSummary] =
    useState(true);
  const [targetRssi, setTargetRssi] = useState(-70);
  const [maxRecommendations, setMaxRecommendations] = useState(3);
  const [bandPreference, setBandPreference] =
    useState<RecommendationBand>("auto");
  const [includeChannelPlan, setIncludeChannelPlan] = useState(true);
  const toast = useToast();

  const params = useMemo(
    () => ({
      plano_id: submittedPlanoId,
      ssid: submittedSsid.trim() || undefined,
      bssid: submittedBssid.trim() || undefined,
      metric: submittedMetric,
      include_heatmap_summary: submittedIncludeHeatmapSummary,
    }),
    [
      submittedBssid,
      submittedIncludeHeatmapSummary,
      submittedMetric,
      submittedPlanoId,
      submittedSsid,
    ],
  );

  const query = useCoverageAnalysis(projectId, params);
  const recommendationsMutation = useApRecommendations(projectId);
  const technicalReportMutation = useTechnicalReport(projectId);

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    setSubmittedPlanoId(planoIdInput.trim() ? Number(planoIdInput) : undefined);
    setSubmittedSsid(ssidInput);
    setSubmittedBssid(bssidInput);
    setSubmittedMetric(metric);
    setSubmittedIncludeHeatmapSummary(includeHeatmapSummary);
    recommendationsMutation.reset();
  };

  const handleGenerateRecommendations = (event: React.FormEvent) => {
    event.preventDefault();
    const planoId = query.data?.plano_id ?? submittedPlanoId;
    if (!planoId) {
      return;
    }

    recommendationsMutation.mutate({
      plano_id: planoId,
      target_rssi_dbm: targetRssi,
      max_recommendations: maxRecommendations,
      strategy: "coverage_gap",
      band_preference: bandPreference,
      include_channel_plan: includeChannelPlan,
    });
  };

  const handleExportTechnicalReport = async () => {
    const planoId = query.data?.plano_id ?? submittedPlanoId;
    if (!planoId) {
      toast.error("Selecciona o carga un plano antes de exportar el reporte.");
      return;
    }

    try {
      const result = await technicalReportMutation.mutateAsync({
        plano_id: planoId,
        include_heatmap: true,
        include_coverage_analysis: true,
        include_ap_recommendations: true,
        metric: submittedMetric,
        target_rssi_dbm: targetRssi,
        format: "pdf",
      });

      const url = window.URL.createObjectURL(result.blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = result.filename;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
      toast.exito("Reporte descargado correctamente");
    } catch (error) {
      toast.error(mapTechnicalReportErrorMessage(error));
    }
  };

  if (!Number.isFinite(projectId) || projectId <= 0) {
    return <EmptyState mensaje="Proyecto inválido." />;
  }

  return (
    <div className={styles.page}>
      <div className={styles.header}>
        <div>
          <Link to="/admin/proyectos" className={styles.backLink}>
            <ArrowLeft size={16} aria-hidden="true" />
            Volver a proyectos
          </Link>
          <h1 className={styles.title}>Diagnóstico de cobertura</h1>
          <p className={styles.subtitle}>
            Visualización estructurada del análisis PB-06 para el proyecto #{projectId}.
          </p>
        </div>

        <Button
          variante="secondary"
          onClick={() => {
            void query.refetch();
          }}
          isLoading={query.isFetching}
        >
          <RefreshCw size={16} aria-hidden="true" />
          Actualizar
        </Button>
      </div>

      <form className={styles.toolbar} onSubmit={handleSubmit}>
        <div className={styles.filters}>
          <label className={styles.field}>
            <span className={styles.label}>Plano ID</span>
            <input
              className={styles.input}
              inputMode="numeric"
              placeholder="Opcional"
              value={planoIdInput}
              onChange={(event) => setPlanoIdInput(event.target.value)}
            />
          </label>

          <label className={styles.field}>
            <span className={styles.label}>Métrica</span>
            <select
              className={styles.select}
              value={metric}
              onChange={(event) => setMetric(event.target.value as CoverageMetric)}
            >
              <option value="best_rssi">best_rssi</option>
              <option value="avg_rssi">avg_rssi</option>
            </select>
          </label>

          <label className={styles.field}>
            <span className={styles.label}>SSID</span>
            <input
              className={styles.input}
              placeholder="Ej. Bulldog-5G"
              value={ssidInput}
              onChange={(event) => setSsidInput(event.target.value)}
            />
          </label>

          <label className={styles.field}>
            <span className={styles.label}>BSSID</span>
            <input
              className={styles.input}
              placeholder="AA:BB:CC:DD:EE:FF"
              value={bssidInput}
              onChange={(event) => setBssidInput(event.target.value)}
            />
          </label>
        </div>

        <div className={styles.actions}>
          <label className={styles.checkbox}>
            <input
              type="checkbox"
              checked={includeHeatmapSummary}
              onChange={(event) => setIncludeHeatmapSummary(event.target.checked)}
            />
            Incluir resumen de heatmap
          </label>

          <Button type="submit">Aplicar filtros</Button>
        </div>

        <p className={styles.hint}>
          El panel consulta el backend con <code>/api/proyectos/{projectId}/coverage-analysis</code>.
        </p>
      </form>

      {query.isLoading ? (
        <div className={styles.statusBox}>Cargando diagnóstico…</div>
      ) : query.isError ? (
        <div className={styles.errorBox}>{mapErrorMessage(query.error)}</div>
      ) : query.data ? (
        <>
          <div className={styles.metaLine}>
            <span>Proyecto #{query.data.proyecto_id}</span>
            <span>Plano #{query.data.plano_id}</span>
            <span>
              Generado: {new Date(query.data.generated_at).toLocaleString("es-BO")}
            </span>
          </div>
          <CoverageAnalysisPanel analysis={query.data} />
          <form
            className={styles.secondaryToolbar}
            onSubmit={handleGenerateRecommendations}
          >
            <div>
              <h2 className={styles.toolbarTitle}>Recomendaciones de APs</h2>
              <p className={styles.hint}>
                Genera sugerencias heurísticas con <code>/api/proyectos/{projectId}/ap-recommendations</code>.
              </p>
            </div>

            <div className={styles.filters}>
              <label className={styles.field}>
                <span className={styles.label}>Target RSSI</span>
                <input
                  className={styles.input}
                  type="number"
                  min={-90}
                  max={-40}
                  value={targetRssi}
                  onChange={(event) => setTargetRssi(Number(event.target.value))}
                />
              </label>

              <label className={styles.field}>
                <span className={styles.label}>Máx. recomendaciones</span>
                <input
                  className={styles.input}
                  type="number"
                  min={1}
                  max={10}
                  value={maxRecommendations}
                  onChange={(event) =>
                    setMaxRecommendations(Number(event.target.value))
                  }
                />
              </label>

              <label className={styles.field}>
                <span className={styles.label}>Banda preferida</span>
                <select
                  className={styles.select}
                  value={bandPreference}
                  onChange={(event) =>
                    setBandPreference(event.target.value as RecommendationBand)
                  }
                >
                  <option value="auto">auto</option>
                  <option value="2.4GHz">2.4GHz</option>
                  <option value="5GHz">5GHz</option>
                </select>
              </label>
            </div>

            <div className={styles.actions}>
              <label className={styles.checkbox}>
                <input
                  type="checkbox"
                  checked={includeChannelPlan}
                  onChange={(event) =>
                    setIncludeChannelPlan(event.target.checked)
                  }
                />
                Incluir plan de canal
              </label>

              <Button type="submit" isLoading={recommendationsMutation.isPending}>
                Generar recomendaciones
              </Button>
            </div>
          </form>
          <APRecommendationsPanel
            result={recommendationsMutation.data ?? null}
            isLoading={recommendationsMutation.isPending}
            errorMessage={recommendationsMutation.error ? mapErrorMessage(recommendationsMutation.error) : null}
          />
          <section className={styles.secondaryToolbar}>
            <div>
              <h2 className={styles.toolbarTitle}>Reporte técnico PDF</h2>
              <p className={styles.hint}>
                Exporta un cierre descargable con <code>/api/proyectos/{projectId}/technical-report</code>.
              </p>
            </div>

            <div className={styles.actions}>
              <Button
                type="button"
                variante="secondary"
                onClick={() => {
                  void handleExportTechnicalReport();
                }}
                isLoading={technicalReportMutation.isPending}
              >
                Exportar reporte PDF
              </Button>
            </div>

            {technicalReportMutation.isSuccess ? (
              <div className={styles.statusBox}>
                Reporte descargado correctamente.
              </div>
            ) : null}

            {technicalReportMutation.isError ? (
              <div className={styles.errorBox}>
                {mapTechnicalReportErrorMessage(technicalReportMutation.error)}
              </div>
            ) : null}
          </section>
        </>
      ) : (
        <EmptyState mensaje="No hay diagnóstico disponible." />
      )}
    </div>
  );
}

function mapErrorMessage(error: unknown): string {
  if (error instanceof AxiosError) {
    const status = error.response?.status;
    const detail = (error.response?.data as BackendError | undefined)?.detail;

    if (status === 401) {
      return "La sesión expiró. Vuelve a iniciar sesión para consultar el diagnóstico.";
    }
    if (status === 404) {
      return detail ?? "Proyecto no encontrado.";
    }
    if (status === 409) {
      return detail ?? "El proyecto no tiene datos suficientes para generar el diagnóstico.";
    }
    if (!error.response) {
      return "No se pudo conectar con el backend. Revisa tu conexión.";
    }
    return detail ?? "Ocurrió un error inesperado al cargar el diagnóstico.";
  }

  return "Ocurrió un error inesperado al cargar el diagnóstico.";
}

function mapTechnicalReportErrorMessage(error: unknown): string {
  if (
    error instanceof Error &&
    error.message === "El backend no devolvió un PDF válido."
  ) {
    return "La respuesta del backend no es un PDF válido.";
  }

  if (error instanceof AxiosError) {
    const status = error.response?.status;
    const detail = (error.response?.data as BackendError | undefined)?.detail;

    if (status === 401) {
      return "La sesión expiró. Vuelve a iniciar sesión para exportar el reporte.";
    }
    if (status === 404) {
      return detail ?? "Proyecto no encontrado.";
    }
    if (status === 409) {
      return detail ?? "El proyecto no tiene datos suficientes para generar el reporte.";
    }
    if (status === 422) {
      return detail ?? "Los parámetros del reporte no son válidos.";
    }
    if (!error.response) {
      return "No se pudo conectar con el backend para descargar el reporte.";
    }
    return detail ?? "Ocurrió un error inesperado al exportar el reporte.";
  }

  return "Ocurrió un error inesperado al exportar el reporte.";
}
