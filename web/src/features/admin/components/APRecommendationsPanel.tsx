import type { APRecommendationResult } from "../types";
import styles from "./APRecommendationsPanel.module.css";

interface Props {
  result: APRecommendationResult | null;
  isLoading: boolean;
  errorMessage?: string | null;
}

export default function APRecommendationsPanel({
  result,
  isLoading,
  errorMessage,
}: Props) {
  return (
    <section className={styles.section}>
      <div className={styles.header}>
        <div>
          <h2 className={styles.title}>Recomendaciones de APs</h2>
          <p className={styles.subtitle}>
            Sugerencias heurísticas para reforzar cobertura y reducir conflictos.
          </p>
        </div>
        {result ? <span className={styles.pill}>{result.strategy}</span> : null}
      </div>

      {isLoading ? (
        <div className={styles.infoBox}>Generando recomendaciones…</div>
      ) : errorMessage ? (
        <div className={styles.errorBox}>{errorMessage}</div>
      ) : !result ? (
        <div className={styles.emptyBox}>
          Genera recomendaciones desde esta pantalla para evaluar posiciones óptimas de AP.
        </div>
      ) : (
        <div className={styles.wrapper}>
          {result.warnings.length > 0 && (
            <div className={styles.warningList}>
              {result.warnings.map((warning, index) => (
                <div key={`${warning}-${index}`} className={styles.warningBox}>
                  {warning}
                </div>
              ))}
            </div>
          )}

          {result.recommendations.length === 0 ? (
            <div className={styles.emptyBox}>
              No se requieren nuevos APs con el objetivo actual.
            </div>
          ) : (
            <div className={styles.recommendationList}>
              {result.recommendations.map((recommendation) => (
                <article
                  key={recommendation.id}
                  className={styles.recommendationCard}
                >
                  <div className={styles.recommendationTop}>
                    <span className={styles.recommendationId}>
                      {recommendation.id}
                    </span>
                    <span className={styles.confidence}>
                      Confianza {Math.round(recommendation.confidence * 100)}%
                    </span>
                  </div>

                  <div className={styles.metaGrid}>
                    <div className={styles.metaItem}>
                      <strong>Posición</strong>
                      <span>
                        x={recommendation.x}, y={recommendation.y}
                      </span>
                    </div>
                    <div className={styles.metaItem}>
                      <strong>Banda / canal</strong>
                      <span>
                        {recommendation.band} / {recommendation.channel}
                      </span>
                    </div>
                    <div className={styles.metaItem}>
                      <strong>Potencia</strong>
                      <span>
                        {recommendation.tx_power} ({recommendation.tx_power_fraction})
                      </span>
                    </div>
                    <div className={styles.metaItem}>
                      <strong>RSSI esperado</strong>
                      <span>{recommendation.expected_rssi_dbm} dBm</span>
                    </div>
                  </div>

                  <p className={styles.reason}>{recommendation.reason}</p>
                  <p className={styles.covers}>
                    <strong>Cubre:</strong>{" "}
                    {recommendation.covers_findings.length > 0
                      ? recommendation.covers_findings.join(", ")
                      : "sin hallazgos asociados"}
                  </p>

                  {recommendation.warnings.length > 0 && (
                    <div className={styles.warningList}>
                      {recommendation.warnings.map((warning, index) => (
                        <div
                          key={`${recommendation.id}-${index}`}
                          className={styles.warningBox}
                        >
                          {warning}
                        </div>
                      ))}
                    </div>
                  )}
                </article>
              ))}
            </div>
          )}

          <div className={styles.assumptionsList}>
            {result.assumptions.map((assumption, index) => (
              <div key={`${assumption}-${index}`} className={styles.listItem}>
                {assumption}
              </div>
            ))}
          </div>
        </div>
      )}
    </section>
  );
}
