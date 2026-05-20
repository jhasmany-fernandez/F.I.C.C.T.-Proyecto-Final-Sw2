/**
 * Pantalla de inicio de sesión para el panel administrativo.
 * Sp1-08 — PB-13 (CA-4 admin necesita login).
 */

import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Eye, EyeOff, Radio } from "lucide-react";
import {
  clearRememberedEmail,
  getRememberedEmail,
  setRememberedEmail,
  useAuth,
} from "@/features/auth/hooks/useAuth";
import { Button } from "@/shared/components";
import styles from "./LoginAdmin.module.css";

export default function LoginAdmin() {
  const navigate = useNavigate();
  const { iniciarSesion, isLoading, error, isAuthenticated, usuario } =
    useAuth();

  const [email, setEmail] = useState(() => getRememberedEmail());
  const [password, setPassword] = useState("");
  const [mostrarPassword, setMostrarPassword] = useState(false);
  const [recordarme, setRecordarme] = useState(() => !!getRememberedEmail());
  const [errLocal, setErrLocal] = useState<string | null>(null);

  useEffect(() => {
    if (isAuthenticated && usuario?.rol === "admin") {
      navigate("/admin/usuarios", { replace: true });
    }
  }, [isAuthenticated, navigate, usuario]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrLocal(null);
    if (!email.trim() || !password) {
      setErrLocal("Ingrese email y contraseña.");
      return;
    }
    try {
      const emailNormalizado = email.trim();
      await iniciarSesion(emailNormalizado, password, recordarme);
      if (recordarme) {
        setRememberedEmail(emailNormalizado);
      } else {
        clearRememberedEmail();
      }
      navigate("/admin/usuarios", { replace: true });
    } catch {
      // El error ya está en el store
    }
  };

  const mensajeError = errLocal ?? error;

  return (
    <div className={styles.container}>
      <div className={styles.card}>
        <div className={styles.logo}>
          <Radio size={48} strokeWidth={1.5} aria-hidden="true" />
        </div>
        <h1 className={styles.titulo}>Wireless HeatMapper</h1>
        <p className={styles.subtitulo}>Panel Administrativo — Bulldog Tech.</p>

        <form onSubmit={handleSubmit} className={styles.form} noValidate>
          {mensajeError && (
            <div className={styles.alerta} role="alert">
              {mensajeError}
            </div>
          )}

          <label className={styles.label} htmlFor="email">
            Correo electrónico
          </label>
          <input
            id="email"
            type="email"
            className={styles.input}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            autoComplete="username"
            placeholder="admin@bulldogtech.bo"
            disabled={isLoading}
            required
          />

          <label className={styles.label} htmlFor="password">
            Contraseña
          </label>
          <div className={styles.passwordWrapper}>
            <input
              id="password"
              type={mostrarPassword ? "text" : "password"}
              className={styles.input}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              placeholder="••••••••"
              disabled={isLoading}
              required
            />
            <button
              type="button"
              className={styles.togglePassword}
              onClick={() => setMostrarPassword((v) => !v)}
              aria-label={
                mostrarPassword ? "Ocultar contraseña" : "Mostrar contraseña"
              }
            >
              {mostrarPassword ? (
                <EyeOff size={18} aria-hidden="true" />
              ) : (
                <Eye size={18} aria-hidden="true" />
              )}
            </button>
          </div>

          <label className={styles.recordarme}>
            <input
              type="checkbox"
              checked={recordarme}
              onChange={(e) => setRecordarme(e.target.checked)}
              disabled={isLoading}
            />
            <span>Recuérdame</span>
          </label>

          <Button
            type="submit"
            fullWidth
            isLoading={isLoading}
            className={styles.botonSubmit}
          >
            {isLoading ? "Iniciando sesión…" : "Iniciar sesión"}
          </Button>
        </form>
      </div>
    </div>
  );
}
