const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const fs = require('fs-extra');
const { spawn } = require('child_process');
const bcrypt = require('bcryptjs');

// Variables globales
let mainWindow;
let isDev = false;
let userConfigPath;
let powershellBridgePath;

// Configurar rutas según el entorno
if (process.env.NODE_ENV === 'development') {
  isDev = true;
  userConfigPath = path.join(__dirname, 'user-config.json');
  powershellBridgePath = path.join(__dirname, 'powershell-bridge');
} else {
  // En producción, usar rutas de recursos
  const resourcesPath = process.resourcesPath || path.join(__dirname, '..');
  userConfigPath = path.join(app.getPath('userData'), 'user-config.json');
  powershellBridgePath = path.join(resourcesPath, 'powershell-bridge');
}

// Función para crear la ventana principal
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1200,
    minHeight: 800,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      enableRemoteModule: false,
      preload: path.join(__dirname, 'preload.cjs'),
      webSecurity: true
    },
    icon: path.join(__dirname, 'assets', 'logo.png'),
    show: false,
    titleBarStyle: 'default',
    autoHideMenuBar: true
  });

  // Cargar la aplicación
  if (isDev) {
    mainWindow.loadURL('http://localhost:5173');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, 'dist', 'index.html'));
  }

  // Mostrar ventana cuando esté lista
  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
    
    // Enfocar la ventana
    if (mainWindow) {
      mainWindow.focus();
    }
  });

  // Manejar cierre de ventana
  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// Función para ejecutar scripts PowerShell con timeout
function executePowerShellScript(scriptPath, args = [], options = {}) {
  return new Promise((resolve, reject) => {
    const timeout = options.timeout || 600000; // 10 minutos por defecto
    
    console.log(`Ejecutando PowerShell: ${scriptPath} con args:`, args);
    
    const psArgs = [
      '-ExecutionPolicy', 'Bypass',
      '-NoProfile',
      '-File', scriptPath,
      ...args
    ];
    
    const child = spawn('powershell.exe', psArgs, {
      cwd: powershellBridgePath,
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true
    });
    
    let stdout = '';
    let stderr = '';
    let isResolved = false;
    
    // Configurar timeout
    const timeoutId = setTimeout(() => {
      if (!isResolved) {
        isResolved = true;
        child.kill('SIGTERM');
        reject(new Error(`PowerShell script timeout después de ${timeout}ms`));
      }
    }, timeout);
    
    // Capturar salida estándar
    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    // Capturar errores (logs van por stderr)
    child.stderr.on('data', (data) => {
      const errorText = data.toString();
      stderr += errorText;
      
      // Enviar logs en tiempo real a la interfaz
      if (mainWindow && !mainWindow.isDestroyed()) {
        try {
          // Parsear logs estructurados
          const lines = errorText.split('\n').filter(line => line.trim());
          lines.forEach(line => {
            const logMatch = line.match(/\[(.*?)\] \[(.*?)\] (.*)/);
            if (logMatch) {
              const [, timestamp, level, message] = logMatch;
              mainWindow.webContents.send('log-message', {
                timestamp,
                level: level.toLowerCase(),
                message: message.trim()
              });
            }
          });
        } catch (e) {
          console.error('Error parseando logs:', e);
        }
      }
    });
    
    // Manejar finalización del proceso
    child.on('close', (code) => {
      clearTimeout(timeoutId);
      
      if (isResolved) return;
      isResolved = true;
      
      console.log(`PowerShell script terminado con código: ${code}`);
      console.log('STDOUT:', stdout);
      console.log('STDERR:', stderr);
      
      if (code === 0) {
        try {
          // Intentar parsear JSON de stdout
          const result = stdout.trim() ? JSON.parse(stdout.trim()) : { success: true };
          resolve(result);
        } catch (e) {
          console.error('Error parseando JSON de PowerShell:', e);
          resolve({
            success: false,
            error: `Error parseando respuesta: ${e.message}`,
            raw_output: stdout,
            raw_error: stderr
          });
        }
      } else {
        reject(new Error(`PowerShell script falló con código ${code}: ${stderr}`));
      }
    });
    
    // Manejar errores del proceso
    child.on('error', (error) => {
      clearTimeout(timeoutId);
      
      if (isResolved) return;
      isResolved = true;
      
      console.error('Error ejecutando PowerShell:', error);
      reject(new Error(`Error ejecutando PowerShell: ${error.message}`));
    });
  });
}

// Función para leer configuración
async function readConfig() {
  try {
    const configPath = path.join(app.getPath('userData'), 'vigencias-config.json');
    if (await fs.pathExists(configPath)) {
      return await fs.readJson(configPath);
    }
    return null;
  } catch (error) {
    console.error('Error leyendo configuración:', error);
    return null;
  }
}

// Función para guardar configuración
async function saveConfig(config) {
  try {
    const configPath = path.join(app.getPath('userData'), 'vigencias-config.json');
    await fs.ensureDir(path.dirname(configPath));
    await fs.writeJson(configPath, config, { spaces: 2 });
    return true;
  } catch (error) {
    console.error('Error guardando configuración:', error);
    throw error;
  }
}

// Función para verificar si existe usuario
async function checkUserExists() {
  try {
    const exists = await fs.pathExists(userConfigPath);
    return { exists };
  } catch (error) {
    console.error('Error verificando usuario:', error);
    return { exists: false };
  }
}

// Función para registrar usuario
async function registerUser(data) {
  try {
    const { username, password } = data;
    
    // Verificar si ya existe un usuario
    if (await fs.pathExists(userConfigPath)) {
      return { success: false, error: 'Ya existe un usuario registrado' };
    }
    
    // Encriptar contraseña
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(password, saltRounds);
    
    // Guardar usuario
    const userData = {
      username,
      password: hashedPassword,
      createdAt: new Date().toISOString()
    };
    
    await fs.ensureDir(path.dirname(userConfigPath));
    await fs.writeJson(userConfigPath, userData, { spaces: 2 });
    
    return { success: true };
  } catch (error) {
    console.error('Error registrando usuario:', error);
    return { success: false, error: error.message };
  }
}

// Función para login de usuario
async function loginUser(data) {
  try {
    const { username, password } = data;
    
    // Verificar si existe el archivo de usuario
    if (!await fs.pathExists(userConfigPath)) {
      return { success: false, error: 'Usuario no encontrado' };
    }
    
    // Leer datos del usuario
    const userData = await fs.readJson(userConfigPath);
    
    // Verificar username
    if (userData.username !== username) {
      return { success: false, error: 'Usuario o contraseña incorrectos' };
    }
    
    // Verificar contraseña
    const isValidPassword = await bcrypt.compare(password, userData.password);
    if (!isValidPassword) {
      return { success: false, error: 'Usuario o contraseña incorrectos' };
    }
    
    return { success: true };
  } catch (error) {
    console.error('Error en login:', error);
    return { success: false, error: error.message };
  }
}

// Función para guardar configuración en PowerShell bridge
async function savePowershellConfig(data) {
  try {
    const configPath = path.join(powershellBridgePath, 'config.json');
    
    // CORRECCION CRITICA: Crear configuracion limpia sin duplicados
    const cleanConfig = {
      firebird: {
        host: data.database?.firebird?.host || "localhost",
        port: parseInt(data.database?.firebird?.port) || 3050,
        user: data.database?.firebird?.user || "sysdba",
        password: data.database?.firebird?.password || "masterkey",
        databasePath: data.database?.firebird?.database || data.paths?.localDbPath || "",
        clientCharset: data.database?.firebird?.clientCharset || "WIN1252",
        dialect: data.database?.firebird?.dialect || 3,
        odbcDriverName: "Firebird/InterBase(r) driver",
        connectionTimeout: data.database?.firebird?.connectionTimeout || 30
      },
      mysql: {
        host: data.database?.mysql?.host || "localhost",
        port: parseInt(data.database?.mysql?.port) || 3306,
        user: data.database?.mysql?.user || "root",
        password: data.database?.mysql?.password || "",
        database: data.database?.mysql?.database || "",
        charset: data.database?.mysql?.charset || "utf8mb4",
        collation: data.database?.mysql?.collation || "utf8mb4_unicode_ci",
        sslEnabled: data.database?.mysql?.sslEnabled || false,
        sslMode: data.database?.mysql?.sslMode || "PREFERRED",
        sslCertPath: data.database?.mysql?.sslCertPath || "",
        sslKeyPath: data.database?.mysql?.sslKeyPath || "",
        sslCAPath: data.database?.mysql?.sslCAPath || ""
      },
      paths: {
        sourceDbPath: data.paths?.sourceDbPath || "",
        localDbPath: data.paths?.localDbPath || "",
        outputPath: data.paths?.outputPath || ""
      },
      rules: {
        diasRevision: data.process?.diasFacturas || 5,
        vigenciaConvenioDias: data.process?.vigenciaConvenio || 35,
        vigenciaCicloEscolarDias: data.process?.vigenciaCicloEscolar || 365,
        vigenciaDiaMes: data.process?.vigenciaDia || 9,
        palabrasProhibidas: data.process?.palabrasExcluidas || ["FONDO DE RESERVA", "FONDO", "INSCRIP", "INSCRIPCION", "ADELANTO", "TARJETA", "TARJE", "ACCESO", "TAG", "APP"],
        palabraConvenio: Array.isArray(data.process?.palabrasConvenio) && data.process.palabrasConvenio.length > 0 ? data.process.palabrasConvenio : (data.process?.palabrasConvenio ? [data.process.palabrasConvenio] : ["CONVENIO"]),
        palabraCicloEscolar: Array.isArray(data.process?.palabrasCicloEscolar) && data.process.palabrasCicloEscolar.length > 0 ? data.process.palabrasCicloEscolar : (data.process?.palabrasCicloEscolar ? [data.process.palabrasCicloEscolar] : ["CICLO ESCOLAR"]),
        todosIdsae: data.process?.todosIdsae || false
      }
    };
    
    // Guardar configuración actualizada
    await fs.ensureDir(path.dirname(configPath));
    await fs.writeJson(configPath, cleanConfig, { spaces: 2 });
    
    return { success: true };
  } catch (error) {
    console.error('Error guardando configuración PowerShell:', error);
    return { success: false, error: error.message };
  }
}

// Handlers IPC
ipcMain.handle('select-file', async (event, options) => {
  try {
    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ['openFile'],
      ...options
    });
    
    return result.canceled ? null : result.filePaths[0];
  } catch (error) {
    console.error('Error seleccionando archivo:', error);
    return null;
  }
});

ipcMain.handle('select-directory', async () => {
  try {
    const result = await dialog.showOpenDialog(mainWindow, {
      properties: ['openDirectory']
    });
    
    return result.canceled ? null : result.filePaths[0];
  } catch (error) {
    console.error('Error seleccionando directorio:', error);
    return null;
  }
});

ipcMain.handle('read-config', readConfig);
ipcMain.handle('save-config', async (event, config) => {
  return await saveConfig(config);
});

ipcMain.handle('check-user-exists', checkUserExists);
ipcMain.handle('register-user', async (event, data) => {
  return await registerUser(data);
});
ipcMain.handle('login-user', async (event, data) => {
  return await loginUser(data);
});
ipcMain.handle('save-powershell-config', async (event, data) => {
  return await savePowershellConfig(data);
});

// Handler para copiar base de datos
ipcMain.handle('copy-database', async (event, sourcePath, destinationPath) => {
  try {
    const scriptPath = path.join(powershellBridgePath, 'VigenciasProcessor.ps1');
    const args = [
      '-Operation', 'copy_database',
      '-SourcePath', sourcePath,
      '-DestinationPath', destinationPath
    ];
    
    return await executePowerShellScript(scriptPath, args, { timeout: 900000 });
  } catch (error) {
    console.error('Error copiando base de datos:', error);
    return { success: false, error: error.message };
  }
});

// Handler para sincronizar clientes
ipcMain.handle('sync-clientes', async () => {
  try {
    const scriptPath = path.join(powershellBridgePath, 'VigenciasProcessor.ps1');
    const args = ['-Operation', 'sync_clientes'];
    
    return await executePowerShellScript(scriptPath, args, { timeout: 300000 });
  } catch (error) {
    console.error('Error sincronizando clientes:', error);
    return { success: false, error: error.message };
  }
});

// Handler para exportar registros
ipcMain.handle('export-registros', async (event, outputPath, diasRevision) => {
  try {
    const scriptPath = path.join(powershellBridgePath, 'VigenciasProcessor.ps1');
    const args = [
      '-Operation', 'export_registros',
      '-OutputPath', outputPath,
      '-DiasFacturas', String(diasRevision)
    ];
    
    return await executePowerShellScript(scriptPath, args, { timeout: 180000 });
  } catch (error) {
    console.error('Error exportando registros:', error);
    return { success: false, error: error.message };
  }
});

// Handler para probar conexión Firebird
ipcMain.handle('test-firebird-connection', async (event, config) => {
  try {
    const scriptPath = path.join(powershellBridgePath, 'VigenciasProcessor.ps1');
    const configJson = JSON.stringify({ firebird: config });
    const args = [
      '-Operation', 'test_firebird_connection',
      '-ConfigJson', `"${configJson.replace(/"/g, '""')}"`
    ];
    
    return await executePowerShellScript(scriptPath, args, { timeout: 60000 });
  } catch (error) {
    console.error('Error probando conexión Firebird:', error);
    return { success: false, error: error.message };
  }
});

// Handler para probar conexión MySQL
ipcMain.handle('test-mysql-connection', async (event, config) => {
  try {
    const scriptPath = path.join(powershellBridgePath, 'VigenciasProcessor.ps1');
    const configJson = JSON.stringify({ mysql: config });
    const args = [
      '-Operation', 'test_mysql_connection',
      '-ConfigJson', `"${configJson.replace(/"/g, '""')}"`
    ];
    
    return await executePowerShellScript(scriptPath, args, { timeout: 60000 });
  } catch (error) {
    console.error('Error probando conexión MySQL:', error);
    return { success: false, error: error.message };
  }
});

// Handler para procesar vigencias completo
ipcMain.handle('process-vigencias', async (event, processConfig, pathConfig, dbConfig) => {
  try {
    const scriptPath = path.join(powershellBridgePath, 'VigenciasProcessor.ps1');
    
    // CORRECCION CRITICA: No enviar JSON, usar solo parametros individuales
    const args = [
      '-Operation', 'process_vigencias',
      '-OutputPath', pathConfig.outputPath,
      '-DiasFacturas', String(processConfig.diasFacturas),
      '-VigenciaDia', String(processConfig.vigenciaDia),
      '-VigenciaConvenio', String(processConfig.vigenciaConvenio),
      '-VigenciaCicloEscolar', String(processConfig.vigenciaCicloEscolar)
    ];
    
    return await executePowerShellScript(scriptPath, args, { timeout: 3000000 }); // 50 minutos
  } catch (error) {
    console.error('Error procesando vigencias:', error);
    return {
      success: false,
      message: error.message,
      facturasProcessed: 0,
      vigenciasUpdated: 0,
      registrosGenerados: 0,
      errors: [error.message],
      archivosGenerados: []
    };
  }
});

// Configuración de la aplicación
app.whenReady().then(() => {
  createWindow();
  
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Configurar política de seguridad
app.on('web-contents-created', (event, contents) => {
  contents.on('new-window', (event, navigationUrl) => {
    event.preventDefault();
  });
  
  contents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    
    if (parsedUrl.origin !== 'http://localhost:5173' && !navigationUrl.startsWith('file://')) {
      event.preventDefault();
    }
  });
});

// Manejar errores no capturados
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
});