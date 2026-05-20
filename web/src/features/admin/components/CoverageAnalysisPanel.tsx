import type {
  AciFinding,
  CciFinding,
  CoverageAnalysis,
  CoverageFinding,
  CoverageSeverity,
} from "../types";
import styles from "./CoverageAnalysisPanel.module.css";

interface Props {
  analysis: CoverageAnalysis;
}

const FINDING_LABELS: Record<CoverageFinding["type"], string> = {
  dead_zone: "Zona muerta",
  weak_zone: "Zona débil",
  overlap: "Solapamiento",
};

const SEVERITY_LABELS: Record<CoverageSeverity, string> = {
  critical: "Crítica",
  high: "Alta",
  medium: "Media",
  low: "Baja",
};

export default function CoverageAnalysisPanel({ analysis }: Props) {
  const { summary, findings, channel_analysis, heatmap_summary } = analysis;

  return (
    <div className={styles.wrapper}>
      <section className={styles.cards} aria-label="Resumen de cobertura">
        <MetricCard
          label="Puntos analizados"
          value={summary.points_analyzed}
          hint={`Métrica ${analysis.metric}`}
        />
        <MetricCard label="Zonas muertas" value={summary.dead_zones_count} />
        <MetricCard label="Zonas débiles" value={summary.weak_zones_count} />
        <MetricCard label="Cobertura OK" value={summary.coverage_ok_count} />
        <MetricCard
          label="% cobertura OK"
          value={`${summary.coverage_ok_percent.toFixed(2)}%`}
        />
        <MetricCard label="RSSI promedio" value={`${summary.avg_rssi_dbm} dBm`} />
        <MetricCard label="Mejor RSSI" value={`${summary.best_rssi_dbm} dBm`} />
        <MetricCard label="Peor RSSI" value={`${summary.worst_rssi_dbm} dBm`} />
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <div>
            <h2 className={styles.sectionTitle}>Hallazgos</h2>
            <p className={styles.sectionText}>
              Diagnóstico estructurado sobre puntos reales del plano.
            </p>
          </div>
        </div>

        {findings.length === 0 ? (
          <div className={styles.emptyBox}>No se detectaron problemas críticos.</div>
        ) : (
          <div className={styles.findingList}>
            {findings.map((finding, index) => (
              <FindingCard key={`${finding.type}-${finding.punto_id}-${index}`} finding={finding} />
            ))}
          </div>
        )}
      </section>

      <section className={styles.section}>
        <div className={styles.sectionHeader}>
          <div>
            <h2 className={styles.sectionTitle}>Conflictos de canal</h2>
            <p className={styles.sectionText}>
              Revisión de CCI y ACI derivada de canales y frecuencias visibles.
            </p>
          </div>
        </div>

        {channel_analysis.cci.length === 0 && channel_analysis.aci.length === 0 ? (
          <div className={styles.emptyBox}>No se detectaron conflictos de canal.</div>
        ) : (
          <div className={styles.channelList}>
            {channel_analysis.cci.map((cci, index) => (
              <ChannelCciCard key={`cci-${cci.channel}-${index}`} cci={cci} />
            ))}
            {channel_analysis.aci.map((aci, index) => (
              <ChannelAciCard key={`aci-${aci.channel}-${aci.adjacent_to}-${index}`} aci={aci} />
            ))}
          </div>
        )}
      </section>

      {heatmap_summary && (
        <section className={styles.section}>
          <div className={styles.sectionHeader}>
            <div>
              <h2 className={styles.sectionTitle}>Resumen del heatmap</h2>
              <p className={styles.sectionText}>
                Señales de contexto entregadas por el backend junto al análisis.
              </p>
            </div>
          </div>

          <div className={styles.metaList}>
            <div className={styles.metaItem}>
              <strong>Puntos usados</strong>
              <span>{heatmap_summary.points_used}</span>
            </div>
            <div className={styles.metaItem}>
              <strong>RSSI mínimo</strong>
              <span>{heatmap_summary.min_rssi} dBm</span>
            </div>
            <div className={styles.metaItem}>
              <strong>RSSI máximo</strong>
              <span>{heatmap_summary.max_rssi} dBm</span>
            </div>
            <div className={styles.metaItem}>
              <strong>Métrica</strong>
              <span>{heatmap_summary.metric}</span>
            </div>
          </div>

          {heatmap_summary.warning && (
            <div className={styles.warningBox} role="status">
              {heatmap_summary.warning}
            </div>
          )}
        </section>
      )}
    </div>
  );
}

function MetricCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string | number;
  hint?: string;
}) {
  return (
    <article className={styles.card}>
      <span className={styles.cardLabel}>{label}</span>
      <strong className={styles.cardValue}>{value}</strong>
      {hint ? <span className={styles.cardHint}>{hint}</span> : null}
    </article>
  );
}

function FindingCard({ finding }: { finding: CoverageFinding }) {
  return (
    <article className={styles.findingItem}>
      <div className={styles.findingTop}>
        <span className={styles.findingType}>{FINDING_LABELS[finding.type]}</span>
        <SeverityBadge severity={finding.severity} />
      </div>
      <p className={styles.findingMessage}>{finding.message}</p>
      <div className={styles.findingMeta}>
        <span>Punto #{finding.punto_id}</span>
        <span>
          x={finding.x}, y={finding.y}
        </span>
        <span>{finding.rssi_dbm} dBm</span>
      </div>
      <p className={styles.findingRecommendation}>
        <strong>Recomendación:</strong> {finding.recommendation}
      </p>
    </article>
  );
}

function ChannelCciCard({ cci }: { cci: CciFinding }) {
  return (
    <article className={styles.channelItem}>
      <div className={styles.channelTop}>
        <span className={styles.channelTitle}>CCI en canal {cci.channel}</span>
        <SeverityBadge severity={cci.severity} />
      </div>
      <div className={styles.channelMeta}>
        <span>Frecuencia: {cci.frequency_mhz ? `${cci.frequency_mhz} MHz` : "—"}</span>
        <span>BSSID visibles: {cci.bssid_count}</span>
      </div>
      <p className={styles.listInline}>{cci.bssids.join(", ")}</p>
      <p className={styles.channelRecommendation}>
        <strong>Recomendación:</strong> {cci.recommendation}
      </p>
    </article>
  );
}

function ChannelAciCard({ aci }: { aci: AciFinding }) {
  return (
    <article className={styles.channelItem}>
      <div className={styles.channelTop}>
        <span className={styles.channelTitle}>
          ACI entre canales {aci.channel} y {aci.adjacent_to}
        </span>
        <SeverityBadge severity={aci.severity} />
      </div>
      <p className={styles.channelRecommendation}>
        <strong>Recomendación:</strong> {aci.recommendation}
      </p>
    </article>
  );
}

function SeverityBadge({ severity }: { severity: CoverageSeverity }) {
  return (
    <span className={`${styles.severity} ${styles[severity]}`}>
      {SEVERITY_LABELS[severity]}
    </span>
  );
}
