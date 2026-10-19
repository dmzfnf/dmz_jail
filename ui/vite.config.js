import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  build: {
    outDir: '../web',
    emptyOutDir: true,
    modulePreload: false,
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        entryFileNames: 'app.js',
        assetFileNames: '[name][extname]'
      }
    }
  },
  plugins: [
    {
      name: 'nui-html',
      enforce: 'post',
      transformIndexHtml: (html) => html.replace(/ crossorigin/g, '')
    }
  ]
});
