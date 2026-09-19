import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "path";

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "dist",
    rollupOptions: {
      input: {
        // the front door
        landing: resolve(__dirname, "index.html"),
        // the product itself
        app: resolve(__dirname, "app/index.html"),
      },
    },
  },
});
