import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// The browser only ever talks to /api on its own origin; Vite forwards it to FastAPI.
// No Informatica host or credential is known to the frontend.
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      "/api": "http://127.0.0.1:8000",
    },
  },
});
