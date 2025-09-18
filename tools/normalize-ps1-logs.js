/* eslint-disable */
const fs = require('fs');

function normalizeText(s) {
  return s
    .replace(/[áàäâãåÁÀÄÂÃÅ]/g, 'a').replace(/[éèëêÉÈËÊ]/g, 'e').replace(/[íìïîÍÌÏÎ]/g, 'i')
    .replace(/[óòöôõøÓÒÖÔÕØ]/g, 'o').replace(/[úùüûÚÙÜÛ]/g, 'u').replace(/[ñÑ]/g, 'n')
    .replace(/[""]/g, '"').replace(/['']/g, "'")
    .replace(/[✓]/g, 'OK').replace(/[✗]/g, 'ERROR').replace(/[⚠]/g, 'WARN')
    .replace(/[çÇ]/g, 'c');
}

function processFile(path) {
  const src = fs.readFileSync(path, 'utf8');
  const lines = src.split(/\r?\n/);
  const out = lines.map(line => {
    const trimmed = line.trim();
    // Si parece SQL, no tocar
    const isSQL = /^(SELECT|UPDATE|INSERT|DELETE|JOIN|FROM|WHERE)\b/i.test(trimmed);
    if (isSQL) return line;
    // Comentario o mensaje de log - normalizar caracteres especiales
    if (trimmed.startsWith('#') || /\b(Log|Write-Output|Write-Error|Write-Host)\b/.test(line)) {
      return normalizeText(line);
    }
    return line;
  }).join('\n');
  fs.writeFileSync(path, out, 'utf8');
  console.log('Normalizado:', path);
}

// Ejecutar normalizacion en archivos PowerShell:
['powershell-bridge/VigenciasProcessor.ps1',
 'powershell-bridge/FirebirdBridge.ps1'].forEach(processFile);