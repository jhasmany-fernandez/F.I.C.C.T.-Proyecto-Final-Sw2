import { defineConfig } from "vitest/config";
import { loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "path";

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  // Carga variables de entorno del directorio raíz del proyecto web.
  // VITE_PROXY_TARGET permite redirigir el proxy del servidor de desarrollo
  // a un host remoto sin modificar el código fuente.
  // Ejemplo: VITE_PROXY_TARGET=http://10.138.57.250:8000 en web/.env.local
  const env = loadEnv(mode, process.cwd(), "VITE_");
  const proxyTarget = env.VITE_PROXY_TARGET ?? "http://localhost:8000";

  return {
    plugins: [react()],
    resolve: {
      alias: {
        "@": resolve(__dirname, "src"),
      },
    },
    server: {
      proxy: {
        "/api": {
          target: proxyTarget,
          changeOrigin: true,
          // Elimina el prefijo /api/ para alinear con el proxy Nginx de producción
          rewrite: (path) => path.replace(/^\/api/, ""),
        },
      },
    },
    test: {
      environment: "jsdom",
      globals: true,
      setupFiles: ["src/test/setup.ts"],
      coverage: {
        provider: "v8",
        reporter: ["text", "lcov"],
      },
    },
  };
});
