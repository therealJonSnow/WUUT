import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // Relative base so a built copy works from a file path or any static host without
  // knowing its deploy URL in advance.
  base: './',
  server: { port: 5173 },
})
