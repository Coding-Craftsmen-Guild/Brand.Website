import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import { fileURLToPath } from 'node:url';

export default defineConfig({
  plugins: [tailwindcss()],
  root: '.',
  // `base` intentionally left at the default ('/'). Dev server serves /@vite/client + /Client/main.ts
  // from root. In prod, the ViteAssetTagHelper hardcodes the '/dist/' prefix when reading the manifest
  // (paths in manifest.json are relative to outDir).

  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./Client', import.meta.url)),
      '@views': fileURLToPath(new URL('./Views', import.meta.url)),
    },
  },

  build: {
    outDir: 'wwwroot/dist',
    manifest: true,
    emptyOutDir: true,
    sourcemap: 'hidden',
    chunkSizeWarningLimit: 500,
    rollupOptions: {
      input: 'Client/main.ts',
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) return 'vendor';
        },
      },
    },
  },

  server: {
    port: 5173,
    strictPort: true,
    origin: 'http://localhost:5173',
    cors: true,
  },
});
