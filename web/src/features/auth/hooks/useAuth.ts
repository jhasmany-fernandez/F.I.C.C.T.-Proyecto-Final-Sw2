/**
 * Hook de autenticación admin (Zustand).
 * Sp1-08 — PB-09 / PB-13.
 */

import { create } from "zustand";
import { login as apiLogin, logout as apiLogout } from "../api/authApi";
import type { AuthState, UsuarioOut } from "../types";
import {
  STORAGE_REMEMBERED_EMAIL,
  STORAGE_REFRESH,
  STORAGE_USER,
  clearSessionStorage,
  getStoredValue,
  setStoredValue,
} from "@/shared/api/client";
import { queryClient } from "@/shared/api/queryClient";

interface AuthStore extends AuthState {
  iniciarSesion: (
    email: string,
    password: string,
    remember?: boolean,
  ) => Promise<void>;
  cerrarSesion: () => Promise<void>;
  /** Carga el usuario desde localStorage si hay un token activo. */
  cargarSesion: () => void;
}

export const useAuth = create<AuthStore>((set) => ({
  usuario: null,
  isAuthenticated: false,
  isReady: false,
  isLoading: false,
  error: null,

  cargarSesion: () => {
    // El token existe: se verifica mediante el interceptor en la primera petición
    // Para el usuario, no hay un endpoint /me en Sprint 1 — se carga desde localStorage
    const raw = getStoredValue(STORAGE_USER);
    const tieneToken = !!getStoredValue(STORAGE_REFRESH);
    if (raw && tieneToken) {
      try {
        const usuario: UsuarioOut = JSON.parse(raw);
        if (usuario.rol !== "admin") {
          limpiarSesionLocal();
          queryClient.clear();
          set({
            usuario: null,
            isAuthenticated: false,
            isReady: true,
            error: "Esta cuenta no tiene acceso al panel administrativo.",
          });
          return;
        }
        set({ usuario, isAuthenticated: true, isReady: true });
      } catch {
        sessionStorage.removeItem(STORAGE_USER);
        localStorage.removeItem(STORAGE_USER);
        set({ usuario: null, isAuthenticated: false, isReady: true });
      }
    } else if (raw && !tieneToken) {
      // Sesión inconsistente: hay perfil guardado pero los tokens expiraron o
      // fueron eliminados. Limpiar para evitar el bucle login ↔ usuarios.
      sessionStorage.removeItem(STORAGE_USER);
      localStorage.removeItem(STORAGE_USER);
      set({ usuario: null, isAuthenticated: false, isReady: true });
    } else {
      set({ usuario: null, isAuthenticated: false, isReady: true });
    }
  },

  iniciarSesion: async (email, password, remember = true) => {
    set({ isLoading: true, error: null });
    try {
      const data = await apiLogin({ email, password }, remember);
      if (data.usuario.rol !== "admin") {
        limpiarSesionLocal();
        queryClient.clear();
        set({
          usuario: null,
          isAuthenticated: false,
          isReady: true,
          isLoading: false,
          error: "Esta cuenta no tiene acceso al panel administrativo.",
        });
        throw new Error("Esta cuenta no tiene acceso al panel administrativo.");
      }
      queryClient.clear();
      setStoredValue(STORAGE_USER, JSON.stringify(data.usuario), remember);
      set({
        usuario: data.usuario,
        isAuthenticated: true,
        isReady: true,
        isLoading: false,
        error: null,
      });
    } catch (err: unknown) {
      const esErrorRolNoAutorizado =
        err instanceof Error &&
        err.message === "Esta cuenta no tiene acceso al panel administrativo.";
      const mensaje = _extraerMensajeError(err);
      set({
        isLoading: false,
        error: esErrorRolNoAutorizado ? err.message : mensaje,
        isAuthenticated: false,
        isReady: true,
      });
      throw err;
    }
  },

  cerrarSesion: async () => {
    const refreshToken = getStoredValue(STORAGE_REFRESH) ?? "";
    try {
      if (refreshToken) await apiLogout(refreshToken);
    } finally {
      limpiarSesionLocal();
      queryClient.clear();
      set({
        usuario: null,
        isAuthenticated: false,
        isReady: true,
        error: null,
      });
    }
  },
}));

function _extraerMensajeError(err: unknown): string {
  if (
    typeof err === "object" &&
    err !== null &&
    "response" in err &&
    typeof (err as { response?: { data?: { detail?: string } } }).response?.data
      ?.detail === "string"
  ) {
    return (err as { response: { data: { detail: string } } }).response.data
      .detail;
  }
  return "Error al iniciar sesión. Verifique su conexión e intente nuevamente.";
}

function limpiarSesionLocal() {
  clearSessionStorage();
}

export function getRememberedEmail(): string {
  return localStorage.getItem(STORAGE_REMEMBERED_EMAIL) ?? "";
}

export function setRememberedEmail(email: string) {
  const normalizedEmail = email.trim();
  if (normalizedEmail) {
    localStorage.setItem(STORAGE_REMEMBERED_EMAIL, normalizedEmail);
  } else {
    localStorage.removeItem(STORAGE_REMEMBERED_EMAIL);
  }
}

export function clearRememberedEmail() {
  localStorage.removeItem(STORAGE_REMEMBERED_EMAIL);
}
