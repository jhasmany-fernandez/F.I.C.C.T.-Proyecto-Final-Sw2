/** Llamadas a la API de autenticación. Sprint 1 — PB-09. */

import {
  apiClient,
  setRememberSession,
  setStoredValue,
  STORAGE_ACCESS,
  STORAGE_REFRESH,
} from "@/shared/api/client";
import type { LoginRequest, TokenResponse } from "../types";

export async function login(
  credentials: LoginRequest,
  remember = true,
): Promise<TokenResponse> {
  const { data } = await apiClient.post<TokenResponse>(
    "/auth/login",
    credentials
  );
  setRememberSession(remember);
  setStoredValue(STORAGE_ACCESS, data.access_token, remember);
  setStoredValue(STORAGE_REFRESH, data.refresh_token, remember);
  return data;
}

export async function logout(refreshToken: string): Promise<void> {
  await apiClient.post("/auth/logout", { refresh_token: refreshToken });
  localStorage.removeItem(STORAGE_ACCESS);
  localStorage.removeItem(STORAGE_REFRESH);
}
