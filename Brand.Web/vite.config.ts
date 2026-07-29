import { defineConfig } from 'vite';
import tailwindcss from '@tailwindcss/vite';
import { fileURLToPath } from 'node:url';

export default defineConfig(({ command }) => ({
  plugins: [tailwindcss()],
  root: '.',
  // Build-only: wwwroot/dist is served under '/dist/' in prod, not at site root. Vite uses `base` to
  // resolve asset URLs it rewrites itself (CSS url(), font references, dynamic imports) — manifest.json
  // entries stay outDir-relative regardless, so ViteAssetTagHelper's manual '/dist/' prefix for entry
  // <script>/<link> tags is unaffected. Left at the default ('/') for the dev server, since
  // ViteAssetTagHelper fetches /@vite/client and the entry module straight from DevServer with no
  // '/dist/' prefix.
  base: command === 'build' ? '/dist/' : '/',

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
}));
