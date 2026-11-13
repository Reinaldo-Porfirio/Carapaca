import { build } from 'esbuild';
import fs from 'fs';
const dev = process.argv.includes('--dev');
const entries = { main: 'src/main.js' };
if (fs.existsSync('src/dev_view.js')) entries.dev_view = 'src/dev_view.js';
for (const [name, entry] of Object.entries(entries)) {
  if (name === 'main' && !fs.existsSync(entry)) continue;
  const inject = name === 'main' && process.argv.includes('--sim') ? ['src/dev_sim.js'] : []; /*DEVSIM*/
  const r = await build({ entryPoints: [entry], inject, bundle: true, format: 'iife', minify: !dev, write: false, target: 'es2020', legalComments: 'none', logLevel: 'warning' });
  const js = r.outputFiles[0].text.replace(/<\/script/g, '<\\/script');
  if (name === 'main') {
    const tpl = fs.readFileSync('src/index.html', 'utf8');
    const css = fs.readFileSync('src/style.css', 'utf8');
    const body = tpl.replace('/*CSS*/', () => css).replace('/*JS*/', () => js);
    fs.writeFileSync('dist/artifact.html', body);
    fs.writeFileSync('dist/index.html', '<!DOCTYPE html>\n<html lang="pt-BR">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n</head>\n<body>\n' + body + '\n</body>\n</html>\n');
    console.log('dist/index.html', (fs.statSync('dist/index.html').size / 1024).toFixed(0) + ' KB');
  } else {
    fs.writeFileSync(`dist/${name}.html`, `<!DOCTYPE html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#111;overflow:hidden}</style></head><body><script>${js}</script></body></html>`);
  }
}
