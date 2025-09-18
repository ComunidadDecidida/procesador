const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  selectFile: (options) => ipcRenderer.invoke('select-file', options),
  selectDirectory: () => ipcRenderer.invoke('select-directory'),
  
  readConfig: () => ipcRenderer.invoke('read-config'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  
  // Funciones de autenticación
  registerUser: (data) => ipcRenderer.invoke('register-user', data),
  loginUser: (data) => ipcRenderer.invoke('login-user', data),
  checkUserExists: () => ipcRenderer.invoke('check-user-exists'),
  savePowershellConfig: (data) => ipcRenderer.invoke('save-powershell-config', data),
  
  copyDatabase: (source, destination) => ipcRenderer.invoke('copy-database', source, destination),
  syncClientes: () => ipcRenderer.invoke('sync-clientes'),
  exportRegistros: (outputPath, diasRevision) => ipcRenderer.invoke('export-registros', outputPath, diasRevision),
  
  testFirebirdConnection: (config) => ipcRenderer.invoke('test-firebird-connection', config),
  testMySQLConnection: (config) => ipcRenderer.invoke('test-mysql-connection', config),
  
  processVigencias: (processConfig, pathConfig, dbConfig) =>
    ipcRenderer.invoke('process-vigencias', processConfig, pathConfig, dbConfig),
  
  onLogMessage: (callback) => {
    ipcRenderer.on('log-message', (event, logEntry) => callback(logEntry));
  },
  
  removeAllListeners: (channel) => {
    ipcRenderer.removeAllListeners(channel);
  }
});

// Exponer bridge adicional para compatibilidad
contextBridge.exposeInMainWorld('bridge', {
  copyDatabase: (source, destination) => ipcRenderer.invoke('copy-database', source, destination),
  syncClientes: () => ipcRenderer.invoke('sync-clientes'),
  exportRegistros: (outputPath, diasRevision) => ipcRenderer.invoke('export-registros', outputPath, diasRevision),
  processVigencias: (processConfig, pathConfig, dbConfig) =>
    ipcRenderer.invoke('process-vigencias', processConfig, pathConfig, dbConfig),
  testFirebird: (config) => ipcRenderer.invoke('test-firebird-connection', config),
  testMySQL: (config) => ipcRenderer.invoke('test-mysql-connection', config)
});
delete window.require;
delete window.exports;
delete window.module;