import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The browser only ever talks to /api on its own origin; Vite forwards it to FastAPI.
// No Informatica host or credential is known to the frontend.
// TXMDM_API_TARGET (dev only) points /api somewhere else, e.g. a local forwarder:
//   PowerShell: $env:TXMDM_API_TARGET="http://127.0.0.1:8010"; npm run dev
const apiTarget = process.env["TXMDM_API_TARGET"] ?? "http://127.0.0.1:8000";

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api": apiTarget,
      // 0.10: the title-bar "API docs" link opens FastAPI's Swagger UI same-origin.
      "/docs": apiTarget,
      "/openapi.json": apiTarget,
    },
  },
});
