/** Tipos TypeScript para el módulo admin. Sprint 1 — PB-13, PB-18, PB-19. */

export interface UsuarioOut {
  id: number;
  nombre: string;
  email: string;
  rol: "admin" | "tecnico";
  activo: boolean;
  created_at: string;
}

export interface UsuarioCreate {
  nombre: string;
  email: string;
  password: string;
  rol: "admin" | "tecnico";
}

export interface UsuarioUpdate {
  nombre?: string;
  email?: string;
  rol?: "admin" | "tecnico";
  activo?: boolean;
  password?: string;
}

export interface ClienteBasicoOut {
  id: number;
  nombre: string;
}

export interface ClienteOut {
  id: number;
  nombre: string;
  activo: boolean;
  created_at: string;
}

export interface ClienteCreate {
  nombre: string;
}

export interface ClienteUpdate {
  nombre?: string;
  activo?: boolean;
}

export interface TecnicoBasicoOut {
  id: number;
  nombre: string;
  email: string;
}

export interface ProyectoListOut {
  id: number;
  nombre: string;
  cliente: ClienteBasicoOut | null;
  estado: "nuevo" | "en_progreso" | "completado" | "archivado";
  ultima_actividad: string;
  cantidad_puntos: number;
  tecnico: TecnicoBasicoOut;
  created_at: string;
}

export interface ProyectosPageOut {
  items: ProyectoListOut[];
  total: number;
  page: number;
  page_size: number;
}

export interface ProyectosFilter {
  tecnico_id?: number;
  estado?: string;
  fecha_desde?: string;
  fecha_hasta?: string;
}

export interface ProyectoReasignarIn {
  tecnico_id: number;
}

export type CoverageMetric = "best_rssi" | "avg_rssi";
export type CoverageSeverity = "critical" | "high" | "medium" | "low";
export type CoverageFindingType = "dead_zone" | "weak_zone" | "overlap";

export interface CoverageSummary {
  points_analyzed: number;
  dead_zones_count: number;
  weak_zones_count: number;
  coverage_ok_count: number;
  coverage_ok_percent: number;
  avg_rssi_dbm: number;
  best_rssi_dbm: number;
  worst_rssi_dbm: number;
}

export interface CoverageFinding {
  type: CoverageFindingType;
  severity: CoverageSeverity;
  message: string;
  punto_id: number;
  x: number;
  y: number;
  rssi_dbm: number;
  recommendation: string;
}

export interface CciFinding {
  channel: number;
  frequency_mhz: number | null;
  severity: CoverageSeverity;
  bssid_count: number;
  bssids: string[];
  recommendation: string;
}

export interface AciFinding {
  channel: number;
  adjacent_to: number;
  severity: CoverageSeverity;
  recommendation: string;
}

export interface ChannelAnalysis {
  cci: CciFinding[];
  aci: AciFinding[];
}

export interface HeatmapSummary {
  metric: CoverageMetric;
  min_rssi: number;
  max_rssi: number;
  points_used: number;
  warning: string | null;
}

export interface CoverageAnalysis {
  proyecto_id: number;
  plano_id: number;
  generated_at: string;
  objective_rssi_dbm: number;
  dead_zone_threshold_dbm: number;
  metric: CoverageMetric;
  summary: CoverageSummary;
  findings: CoverageFinding[];
  channel_analysis: ChannelAnalysis;
  heatmap_summary: HeatmapSummary | null;
}

export interface CoverageAnalysisParams {
  plano_id?: number;
  ssid?: string;
  bssid?: string;
  metric?: CoverageMetric;
  include_heatmap_summary?: boolean;
}

export type RecommendationBand = "auto" | "2.4GHz" | "5GHz";

export interface APRecommendationParams {
  plano_id: number;
  target_rssi_dbm: number;
  max_recommendations: number;
  strategy: "coverage_gap";
  band_preference: RecommendationBand;
  include_channel_plan: boolean;
}

export interface APRecommendationItem {
  id: string;
  x: number;
  y: number;
  band: "2.4GHz" | "5GHz";
  channel: number;
  tx_power: "medium";
  tx_power_fraction: number;
  expected_rssi_dbm: number;
  confidence: number;
  reason: string;
  covers_findings: Array<"dead_zone" | "weak_zone" | "overlap" | "cci" | "aci">;
  warnings: string[];
}

export interface APRecommendationResult {
  proyecto_id: number;
  plano_id: number;
  generated_at: string;
  target_rssi_dbm: number;
  strategy: "coverage_gap";
  recommendations: APRecommendationItem[];
  assumptions: string[];
  warnings: string[];
}

export interface TechnicalReportParams {
  plano_id: number;
  include_heatmap: boolean;
  include_coverage_analysis: boolean;
  include_ap_recommendations: boolean;
  metric: CoverageMetric;
  target_rssi_dbm: number;
  format: "pdf";
}

export interface TechnicalReportDownload {
  blob: Blob;
  filename: string;
  contentType: string;
}
