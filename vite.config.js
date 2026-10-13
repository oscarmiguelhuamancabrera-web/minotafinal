import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { VitePWA } from 'vite-plugin-pwa'

const buildId = process.env.VERCEL_GIT_COMMIT_SHA || process.env.VITE_BUILD_ID || `local-${Date.now()}`

function versionManifestPlugin() {
  return {
    name: 'mi-nota-final-version-manifest',
    generateBundle() {
      this.emitFile({
        type: 'asset',
        fileName: 'version.json',
        source: JSON.stringify({ buildId, generatedAt: new Date().toISOString() })
      })
    }
  }
}

export default defineConfig({
  define: {
    __MN_BUILD_ID__: JSON.stringify(buildId)
  },
  plugins: [
    react(),
    versionManifestPlugin(),
    VitePWA({
      // Una versión nueva se aplicará al volver a abrir la app, sin recargar
      // automáticamente la pantalla mientras el usuario está trabajando.
      registerType: 'prompt',
      workbox: {
        globIgnores: ['version.json'],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.endsWith('/version.json'),
            handler: 'NetworkOnly'
          }
        ]
      },
      includeAssets: ['favicon.png', 'logo.png', 'icon-192.png', 'icon-512.png', 'theme-init.js', 'google-g.svg', 'microsoft.svg'],
      manifest: {
        name: 'Mi Nota Final',
        short_name: 'Mi Nota Final',
        description: 'Calcula tu nota. Conoce tu meta. Aprueba.',
        theme_color: '#7c3aed',
        background_color: '#f7f1ff',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/',
        icons: [
          {
            src: '/icon-192.png',
            sizes: '192x192',
            type: 'image/png'
          },
          {
            src: '/icon-512.png',
            sizes: '512x512',
            type: 'image/png'
          }
        ]
      }
    })
  ]
})
