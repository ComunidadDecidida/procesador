import React, { useState, useEffect } from 'react';
import { Shield, Database, User, Lock, Eye, EyeOff, FileText, FolderOpen, Settings, Monitor, Activity, CheckCircle, XCircle, AlertCircle, Play, Zap, Clock, Calendar, Server, CopySlash as MySQL } from 'lucide-react';
import { configManager } from './utils/config';
import logoImage from '@assets/logo.png';
import { databaseService } from './services/databaseService';
import { schedulerService } from './services/schedulerService';
import ScheduleManager from './components/ScheduleManager';
import { progressService } from './services/progressService';
import { DatabaseConfig, PathConfig, ProcessConfig, ProcessLog, ProcessStatus } from './types';
import LoginScreen from './components/LoginScreen';
import ClockWidget from './components/ClockWidget';

const App: React.FC = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [logs, setLogs] = useState<ProcessLog[]>([]);
  const [processStatus, setProcessStatus] = useState<ProcessStatus>({
    isRunning: false,
    currentStep: '',
    progress: 0,
    lastRun: null
  });

  // Estados de configuración
  const [databaseConfig, setDatabaseConfig] = useState<DatabaseConfig>({
    firebird: {
      host: 'localhost',
      database: 'C:\\SAE\\SAE90EMPRE01.FDB',
      user: 'SYSDBA',
      password: 'masterkey',
      port: '3050',
      clientCharset: 'WIN1252',
      dialect: 3,
      odbcDriverName: 'Firebird/InterBase(r) driver',
      connectionTimeout: 30
    },
    mysql: {
      host: 'localhost',
      port: '3306',
      database: 'vigencias_db',
      user: 'root',
      password: '',
      charset: 'utf8mb4',
      collation: 'utf8mb4_unicode_ci',
      sslEnabled: false,
      sslMode: 'PREFERRED',
      sslCertPath: '',
      sslKeyPath: '',
      sslCAPath: ''
    }
  });

  const [pathConfig, setPathConfig] = useState<PathConfig>({
    sourceDbPath: 'C:\\Users\\LENOVO AIO PC\\Downloads\\SAE90EMPRE01\\SAE90EMPRE01.FDB',
    localDbPath: 'C:\\SAE\\SAE90EMPRE01.FDB',
    outputPath: 'C:\\Users\\LENOVO AIO PC\\Desktop\\pruebas de archivos\\'
  });

  const [processConfig, setProcessConfig] = useState<ProcessConfig>({
    diasFacturas: 5,
    vigenciaDia: 9,
    vigenciaConvenio: 35,
    vigenciaCicloEscolar: 365,
    palabrasExcluidas: ['FONDO DE RESERVA', 'FONDO', 'INSCRIP', 'INSCRIPCION', 'ADELANTO', 'TARJETA', 'TARJE', 'ACCESO', 'TAG', 'APP'],
    palabrasConvenio: ['CONVENIO'],
    palabrasCicloEscolar: ['CICLO ESCOLAR'],
    scheduledExecution: {
      enabled: false,
      times: ['09:00'],
      days: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      lastExecution: null
    }
  });

  // Estados locales para entrada de texto crudo (Paso 6.1)
  const [rawPalabrasExcluidasInput, setRawPalabrasExcluidasInput] = useState('');
  const [rawPalabrasConvenioInput, setRawPalabrasConvenioInput] = useState('');
  const [rawPalabrasCicloEscolarInput, setRawPalabrasCicloEscolarInput] = useState('');

  useEffect(() => {
    loadConfiguration();
    setupLogListener();
    
    // Configurar progreso
    progressService.onProgress((progress, step) => {
      setProcessStatus(prev => ({
        ...prev,
        progress,
        currentStep: step
      }));
    });

    return () => {
      if (window.electronAPI?.removeAllListeners) {
        window.electronAPI.removeAllListeners('log-message');
      }
    };
  }, []);

  // Sincronizar localDbPath con firebird database
  useEffect(() => {
    setDatabaseConfig(prev => ({
      ...prev,
      firebird: {
        ...prev.firebird,
        database: pathConfig.localDbPath
      }
    }));
  }, [pathConfig.localDbPath]);

  // Inicializar estados de entrada cruda cuando cambie la configuración
  useEffect(() => {
    setRawPalabrasExcluidasInput(processConfig.palabrasExcluidas.join(', '));
    setRawPalabrasConvenioInput(processConfig.palabrasConvenio.join(', '));
    setRawPalabrasCicloEscolarInput(processConfig.palabrasCicloEscolar.join(', '));
  }, [processConfig.palabrasExcluidas, processConfig.palabrasConvenio, processConfig.palabrasCicloEscolar]);

  const loadConfiguration = async () => {
    try {
      const config = await configManager.loadConfig();
      if (config) {
        setDatabaseConfig(config.database);
        setPathConfig(config.paths);
        setProcessConfig(config.process);
        
        // Sincronizar localDbPath si existe
        if (config.paths?.localDbPath) {
          setPathConfig(prev => ({
            ...prev,
            localDbPath: config.paths.localDbPath
          }));
        }
      }
    } catch (error) {
      addLog('error', 'Error cargando configuracion', error.message);
    }
  };

  const saveConfiguration = async () => {
    try {
      const configToSave = {
        database: databaseConfig,
        paths: pathConfig,
        process: processConfig,
        lastUpdated: new Date().toISOString()
      };

      await configManager.saveConfig(configToSave);
      
      // Guardar también en PowerShell bridge
      if (window.electronAPI?.savePowershellConfig) {
        await window.electronAPI.savePowershellConfig(configToSave);
      }
      
      addLog('success', 'Configuracion guardada exitosamente');
      
      // Reiniciar scheduler si está habilitado
      if (processConfig.scheduledExecution.enabled) {
        schedulerService.restartScheduler(processConfig, executeVigenciasProcess);
      }
    } catch (error) {
      addLog('error', 'Error guardando configuracion', error.message);
    }
  };

  // Función de guardado con procesamiento de texto crudo (Paso 6.3)
  const saveParametersWithProcessing = async () => {
    try {
      // Procesar las cadenas de texto crudas
      const palabrasExcluidasProcessed = rawPalabrasExcluidasInput
        .split(',')
        .map(s => s.trim())
        .filter(s => s);
      
      const palabrasConvenioProcessed = rawPalabrasConvenioInput
        .split(',')
        .map(s => s.trim())
        .filter(s => s);
      
      const palabrasCicloEscolarProcessed = rawPalabrasCicloEscolarInput
        .split(',')
        .map(s => s.trim())
        .filter(s => s);

      // Actualizar configuración con arreglos procesados
      const updatedProcessConfig = {
        ...processConfig,
        palabrasExcluidas: palabrasExcluidasProcessed,
        palabrasConvenio: palabrasConvenioProcessed.length > 0 ? palabrasConvenioProcessed : ['CONVENIO'],
        palabrasCicloEscolar: palabrasCicloEscolarProcessed.length > 0 ? palabrasCicloEscolarProcessed : ['CICLO ESCOLAR']
      };

      setProcessConfig(updatedProcessConfig);

      // Guardar configuración
      const configToSave = {
        database: databaseConfig,
        paths: pathConfig,
        process: updatedProcessConfig,
        lastUpdated: new Date().toISOString()
      };

      await configManager.saveConfig(configToSave);
      
      if (window.electronAPI?.savePowershellConfig) {
        await window.electronAPI.savePowershellConfig(configToSave);
      }
      
      addLog('success', 'Parametros guardados exitosamente');
      
      // Reiniciar scheduler si está habilitado
      if (updatedProcessConfig.scheduledExecution.enabled) {
        schedulerService.restartScheduler(updatedProcessConfig, executeVigenciasProcess);
      }
    } catch (error) {
      addLog('error', 'Error guardando parametros', error.message);
    }
  };

  const setupLogListener = () => {
    if (window.electronAPI?.onLogMessage) {
      window.electronAPI.onLogMessage((logEntry) => {
        const processLog: ProcessLog = {
          id: Date.now().toString(),
          timestamp: logEntry.timestamp,
          process: 'PowerShell',
          message: logEntry.message,
          status: logEntry.level.toLowerCase() === 'success' ? 'success' : 
                  logEntry.level.toLowerCase() === 'error' ? 'error' :
                  logEntry.level.toLowerCase() === 'warn' ? 'warning' : 'info'
        };
        
        setLogs(prev => [processLog, ...prev.slice(0, 99)]);
        
        // Actualizar progreso basado en logs
        progressService.updateProgress(processLog);
      });
    }
  };

  const addLog = (status: ProcessLog['status'], process: string, message?: string) => {
    const log: ProcessLog = {
      id: Date.now().toString(),
      timestamp: new Date().toISOString(),
      process,
      message: message || process,
      status
    };
    setLogs(prev => [log, ...prev.slice(0, 99)]);
  };

  const selectPath = async (pathType: 'sourceDb' | 'localDbDir' | 'outputDir' | 'sslCert' | 'sslKey' | 'sslCA') => {
    try {
      let selectedPath = null;
      
      if (pathType === 'outputDir' || pathType === 'localDbDir') {
        selectedPath = await window.electronAPI?.selectDirectory();
      } else if (pathType === 'sslCert' || pathType === 'sslKey' || pathType === 'sslCA') {
        selectedPath = await window.electronAPI?.selectFile({
          title: pathType === 'sslCert' ? 'Seleccionar certificado SSL' : 
                 pathType === 'sslKey' ? 'Seleccionar clave privada SSL' : 
                 'Seleccionar certificado CA',
          filters: [
            { name: 'Certificados', extensions: ['pem', 'crt', 'cer', 'key'] },
            { name: 'Todos los archivos', extensions: ['*'] }
          ]
        });
      } else {
        selectedPath = await window.electronAPI?.selectFile({
          title: pathType === 'sourceDb' ? 'Seleccionar archivo de base de datos origen' : 'Seleccionar ubicacion local',
          filters: [
            { name: 'Archivos Firebird', extensions: ['fdb', 'gdb'] },
            { name: 'Todos los archivos', extensions: ['*'] }
          ]
        });
      }

      if (selectedPath) {
        if (pathType === 'sourceDb') {
          setPathConfig(prev => ({ ...prev, sourceDbPath: selectedPath }));
        } else if (pathType === 'localDbDir') {
          const fileName = 'SAE90EMPRE01_local.FDB';
          const fullPath = selectedPath.endsWith('\\') ? selectedPath + fileName : selectedPath + '\\' + fileName;
          setPathConfig(prev => ({ ...prev, localDbPath: fullPath }));
          setDatabaseConfig(prev => ({
            ...prev,
            firebird: { ...prev.firebird, database: fullPath }
          }));
        } else if (pathType === 'outputDir') {
          setPathConfig(prev => ({ ...prev, outputPath: selectedPath }));
        } else if (pathType === 'sslCert') {
          setDatabaseConfig(prev => ({
            ...prev,
            mysql: { ...prev.mysql, sslCertPath: selectedPath }
          }));
        } else if (pathType === 'sslKey') {
          setDatabaseConfig(prev => ({
            ...prev,
            mysql: { ...prev.mysql, sslKeyPath: selectedPath }
          }));
        } else if (pathType === 'sslCA') {
          setDatabaseConfig(prev => ({
            ...prev,
            mysql: { ...prev.mysql, sslCAPath: selectedPath }
          }));
        }
        
        addLog('info', 'Ruta seleccionada', selectedPath);
      }
    } catch (error) {
      addLog('error', 'Error seleccionando ruta', error.message);
    }
  };

  const executeVigenciasProcess = async () => {
    if (processStatus.isRunning) {
      addLog('warning', 'Proceso ya en ejecucion');
      return;
    }

    setProcessStatus(prev => ({ ...prev, isRunning: true, progress: 0 }));
    progressService.reset();

    try {
      addLog('info', 'Iniciando proceso completo de vigencias...');
      
      const result = await databaseService.processVigencias(processConfig, pathConfig, databaseConfig);
      
      if (result.success) {
        addLog('success', 'Proceso completado exitosamente', 
          `${result.facturasProcessed} facturas procesadas, ${result.vigenciasUpdated} vigencias actualizadas, ${result.registrosGenerados} registros generados`);
        setProcessStatus(prev => ({ 
          ...prev, 
          lastRun: new Date().toISOString(),
          progress: 100
        }));
        progressService.complete();
      } else {
        addLog('error', 'Error en proceso', result.message);
        if (result.errors && result.errors.length > 0) {
          result.errors.forEach(error => addLog('error', 'Error detalle', error));
        }
      }
    } catch (error) {
      addLog('error', 'Error ejecutando proceso', error.message);
    } finally {
      setProcessStatus(prev => ({ 
        ...prev, 
        isRunning: false, 
        currentStep: '',
        progress: 0
      }));
    }
  };

  const toggleScheduler = () => {
    const newEnabled = !processConfig.scheduledExecution.enabled;
    setProcessConfig(prev => ({
      ...prev,
      scheduledExecution: {
        ...prev.scheduledExecution,
        enabled: newEnabled
      }
    }));

    if (newEnabled) {
      schedulerService.startScheduler(processConfig, executeVigenciasProcess);
      addLog('info', 'Programacion automatica activada');
    } else {
      schedulerService.stopScheduler();
      addLog('info', 'Programacion automatica desactivada');
    }
  };

  // Inicializar scheduler al cargar
  useEffect(() => {
    if (processConfig.scheduledExecution.enabled) {
      schedulerService.startScheduler(processConfig, executeVigenciasProcess);
    }
    return () => {
      schedulerService.stopScheduler();
    };
  }, [processConfig.scheduledExecution.enabled]);

  if (!isAuthenticated) {
    return <LoginScreen onAuthenticated={() => setIsAuthenticated(true)} />;
  }

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Header */}
      <header className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center">
              <div className="w-8 h-8 mr-3 flex items-center justify-center">
                <img
                  src={logoImage}
                  alt="ETI Logo"
                  className="w-8 h-8 object-contain"
                  onError={(e) => {
                    (e.currentTarget as HTMLImageElement).style.display = 'none';
                    const sibling = e.currentTarget.nextElementSibling as HTMLElement | null;
                    if (sibling) {
                      sibling.style.display = 'block';
                    }
                  }}
                />
                <Shield className="w-8 h-8 text-blue-600 hidden" />
              </div>
              <h1 className="text-xl font-semibold text-gray-900">
                Sistema de Gestion de Vigencias
              </h1>
            </div>
            <div className="flex items-center space-x-4">
              <ClockWidget />
              <div className="text-sm text-gray-500">
                ETI - Enlaces en Telecomunicaciones Inalambricas
              </div>
            </div>
          </div>
        </div>
      </header>

      {/* Navigation */}
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex space-x-8">
            {[
              { id: 'dashboard', label: 'Dashboard', icon: FileText },
              { id: 'configuration', label: 'Configuracion', icon: Settings },
              { id: 'parameters', label: 'Parametros', icon: Zap },
              { id: 'monitor', label: 'Monitor', icon: Monitor },
              { id: 'logs', label: 'Logs', icon: Activity }
            ].map(tab => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center px-3 py-4 text-sm font-medium border-b-2 transition-colors ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <tab.icon className="w-4 h-4 mr-2" />
                {tab.label}
              </button>
            ))}
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'dashboard' && (
          <div className="space-y-6">
            {/* Status Header */}
            <div className="bg-gradient-to-r from-blue-600 to-indigo-600 rounded-lg p-6 text-white">
              <div className="flex items-center justify-between">
                <div>
                  <h1 className="text-2xl font-bold mb-2">Sistema de Gestion de Vigencias</h1>
                  <p className="text-blue-100">Enlaces en Telecomunicaciones Inalambricas (ETI)</p>
                </div>
                <div className="text-right">
                  <div className="flex items-center space-x-2 mb-2">
                    {processStatus.isRunning ? (
                      <>
                        <Monitor className="w-5 h-5 animate-pulse" />
                        <span>Procesando... {processStatus.progress}%</span>
                      </>
                    ) : (
                      <>
                        <CheckCircle className="w-5 h-5" />
                        <span>Listo</span>
                      </>
                    )}
                  </div>
                  {processStatus.lastRun && (
                    <p className="text-sm text-blue-200">
                      Ultima ejecucion: {new Date(processStatus.lastRun).toLocaleString('es-ES')}
                    </p>
                  )}
                </div>
              </div>
              
              {processStatus.isRunning && (
                <div className="mt-4">
                  <div className="w-full bg-blue-800 rounded-full h-2">
                    <div 
                      className="bg-white h-2 rounded-full transition-all duration-300"
                      style={{ width: `${processStatus.progress}%` }}
                    ></div>
                  </div>
                  <p className="text-xs text-blue-200 mt-1">
                    {processStatus.currentStep || `${processStatus.progress}% completado`}
                  </p>
                </div>
              )}
            </div>

            {/* Quick Actions */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-white rounded-lg shadow-md p-6">
                <div className="flex items-center">
                  <Database className="w-8 h-8 text-blue-600 mr-3" />
                  <div>
                    <h3 className="font-semibold text-gray-800">Base de Datos</h3>
                    <p className="text-sm text-gray-600">Firebird + MySQL</p>
                  </div>
                </div>
                <div className="mt-4 flex space-x-2">
                  <button
                    onClick={async () => {
                      try {
                        addLog('info', 'Probando conexion Firebird...');
                        const cleanConfig = {};
                        for (const [key, value] of Object.entries(databaseConfig.firebird)) {
                          if (value !== null && value !== '') {
                            cleanConfig[key] = value;
                          }
                        }
                        const result = await databaseService.testFirebirdConnection(cleanConfig);
                        if (result.success) {
                          addLog('success', 'Conexion Firebird exitosa', result.message);
                        } else {
                          addLog('error', 'Error conexion Firebird', result.error);
                        }
                      } catch (error) {
                        addLog('error', 'Error probando conexion Firebird', error.message);
                      }
                    }}
                    className="flex-1 bg-blue-100 hover:bg-blue-200 text-blue-800 px-3 py-2 rounded text-sm font-medium transition-colors"
                  >
                    Probar Firebird
                  </button>
                  <button
                    onClick={async () => {
                      try {
                        addLog('info', 'Probando conexion MySQL...');
                        const cleanConfig = {};
                        for (const [key, value] of Object.entries(databaseConfig.mysql)) {
                          if (value !== null && value !== '') {
                            cleanConfig[key] = value;
                          }
                        }
                        const result = await databaseService.testMySQLConnection(cleanConfig);
                        if (result.success) {
                          addLog('success', 'Conexion MySQL exitosa', result.message);
                        } else {
                          addLog('error', 'Error conexion MySQL', result.error);
                        }
                      } catch (error) {
                        addLog('error', 'Error probando conexion MySQL', error.message);
                      }
                    }}
                    className="flex-1 bg-green-100 hover:bg-green-200 text-green-800 px-3 py-2 rounded text-sm font-medium transition-colors"
                  >
                    Probar MySQL
                  </button>
                </div>
              </div>

              <div className="bg-white rounded-lg shadow-md p-6">
                <div className="flex items-center">
                  <Clock className="w-8 h-8 text-green-600 mr-3" />
                  <div>
                    <h3 className="font-semibold text-gray-800">Programacion</h3>
                    <p className="text-sm text-gray-600">
                      {processConfig.scheduledExecution.enabled ? 'Activa' : 'Inactiva'}
                    </p>
                  </div>
                </div>
                <div className="mt-4">
                  <button
                    onClick={toggleScheduler}
                    className={`w-full px-3 py-2 rounded text-sm font-medium transition-colors ${
                      processConfig.scheduledExecution.enabled
                        ? 'bg-red-100 hover:bg-red-200 text-red-800'
                        : 'bg-green-100 hover:bg-green-200 text-green-800'
                    }`}
                  >
                    {processConfig.scheduledExecution.enabled ? 'Desactivar' : 'Activar'}
                  </button>
                </div>
              </div>

              <div className="bg-white rounded-lg shadow-md p-6">
                <div className="flex items-center">
                  <Play className="w-8 h-8 text-orange-600 mr-3" />
                  <div>
                    <h3 className="font-semibold text-gray-800">Proceso Manual</h3>
                    <p className="text-sm text-gray-600">Ejecutar ahora</p>
                  </div>
                </div>
                <div className="mt-4">
                  <button
                    onClick={executeVigenciasProcess}
                    disabled={processStatus.isRunning}
                    className="w-full bg-orange-600 hover:bg-orange-700 disabled:bg-gray-400 text-white px-3 py-2 rounded text-sm font-medium transition-colors flex items-center justify-center"
                  >
                    {processStatus.isRunning ? (
                      <>
                        <Monitor className="w-4 h-4 mr-2 animate-spin" />
                        Procesando...
                      </>
                    ) : (
                      <>
                        <Play className="w-4 h-4 mr-2" />
                        Iniciar Proceso
                      </>
                    )}
                  </button>
                </div>
              </div>
            </div>

            {/* Recent Activity */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h3 className="text-lg font-semibold text-gray-800 mb-4 flex items-center">
                <Activity className="w-5 h-5 mr-2" />
                Actividad Reciente
              </h3>
              <div className="space-y-2 max-h-64 overflow-y-auto">
                {logs.slice(0, 10).map(log => (
                  <div key={log.id} className="flex items-start space-x-3 p-2 rounded-lg bg-gray-50">
                    <div className="flex-shrink-0 mt-1">
                      {log.status === 'success' && <CheckCircle className="w-4 h-4 text-green-600" />}
                      {log.status === 'error' && <XCircle className="w-4 h-4 text-red-600" />}
                      {log.status === 'warning' && <AlertCircle className="w-4 h-4 text-yellow-600" />}
                      {log.status === 'info' && <AlertCircle className="w-4 h-4 text-blue-600" />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-gray-800">{log.message}</p>
                      <p className="text-xs text-gray-500">
                        {new Date(log.timestamp).toLocaleString('es-ES')} - {log.process}
                      </p>
                    </div>
                  </div>
                ))}
                {logs.length === 0 && (
                  <p className="text-gray-500 text-center py-4">No hay actividad reciente</p>
                )}
              </div>
            </div>
          </div>
        )}

        {activeTab === 'configuration' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-md p-6">
              <h2 className="text-xl font-semibold text-gray-800 mb-6 flex items-center">
                <Settings className="w-6 h-6 mr-2" />
                Configuracion del Sistema
              </h2>

              {/* Rutas de Archivos */}
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4 flex items-center">
                  <FolderOpen className="w-5 h-5 mr-2" />
                  Rutas de Archivos
                </h3>
                <div className="grid grid-cols-1 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Base de Datos Origen (Red)
                    </label>
                    <div className="flex">
                      <input
                        type="text"
                        value={pathConfig.sourceDbPath}
                        onChange={(e) => {
                          setPathConfig(prev => ({ ...prev, sourceDbPath: e.target.value }));
                        }}
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="C:\\Users\\LENOVO AIO PC\\Downloads\\SAE90EMPRE01\\SAE90EMPRE01.FDB"
                      />
                      <button
                        onClick={() => selectPath('sourceDb')}
                        className="px-4 py-2 bg-blue-600 text-white rounded-r-md hover:bg-blue-700 transition-colors"
                      >
                        Buscar
                      </button>
                    </div>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Directorio Local para Base de Datos
                    </label>
                    <div className="flex">
                      <input
                        type="text"
                        value={pathConfig.localDbPath ? pathConfig.localDbPath.replace('\\SAE90EMPRE01_local.FDB', '') : ''}
                        onChange={(e) => {
                          const dirPath = e.target.value;
                          const fileName = 'SAE90EMPRE01_local.FDB';
                          const fullPath = dirPath.endsWith('\\') ? dirPath + fileName : dirPath + '\\' + fileName;
                          setPathConfig(prev => ({ ...prev, localDbPath: fullPath }));
                          setDatabaseConfig(prev => ({
                            ...prev,
                            firebird: { ...prev.firebird, database: fullPath }
                          }));
                        }}
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="C:\\Users\\LENOVO AIO PC\\AppData\\Local\\SAE\\"
                      />
                      <button
                        onClick={() => selectPath('localDbDir')}
                        className="px-4 py-2 bg-blue-600 text-white rounded-r-md hover:bg-blue-700 transition-colors"
                      >
                        Buscar
                      </button>
                    </div>
                    <p className="text-xs text-gray-500 mt-1">
                      Seleccione el directorio donde se guardara la copia local. El archivo se llamara "SAE90EMPRE01_local.FDB"
                    </p>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Directorio de Salida
                    </label>
                    <div className="flex">
                      <input
                        type="text"
                        value={pathConfig.outputPath}
                        onChange={(e) => setPathConfig(prev => ({ ...prev, outputPath: e.target.value }))}
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="C:\\Users\\LENOVO AIO PC\\Desktop\\pruebas de archivos\\"
                      />
                      <button
                        onClick={() => selectPath('outputDir')}
                        className="px-4 py-2 bg-blue-600 text-white rounded-r-md hover:bg-blue-700 transition-colors"
                      >
                        Buscar
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              {/* Configuracion Firebird */}
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4 flex items-center">
                  <Database className="w-5 h-5 mr-2" />
                  Configuracion Firebird
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Host</label>
                    <input
                      type="text"
                      value={databaseConfig.firebird.host}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, host: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="localhost"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Puerto</label>
                    <input
                      type="text"
                      value={databaseConfig.firebird.port}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, port: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="3050"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Usuario</label>
                    <input
                      type="text"
                      value={databaseConfig.firebird.user}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, user: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="SYSDBA"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Contrasena</label>
                    <input
                      type="password"
                      value={databaseConfig.firebird.password}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, password: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="masterkey"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Charset Cliente</label>
                    <select
                      value={databaseConfig.firebird.clientCharset}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, clientCharset: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="WIN1252">WIN1252 (Recomendado para SAE 9)</option>
                      <option value="UTF8">UTF8</option>
                      <option value="ISO8859_1">ISO8859_1</option>
                      <option value="NONE">NONE</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Dialecto SQL</label>
                    <select
                      value={databaseConfig.firebird.dialect}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, dialect: parseInt(e.target.value) }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="3">Dialecto 3 (Recomendado)</option>
                      <option value="1">Dialecto 1</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Driver ODBC</label>
                    <input
                      type="text"
                      value={databaseConfig.firebird.odbcDriverName || ''}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, odbcDriverName: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Firebird/InterBase(r) driver"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Timeout Conexion (segundos)</label>
                    <input
                      type="number"
                      min="5"
                      max="300"
                      value={databaseConfig.firebird.connectionTimeout || 30}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        firebird: { ...prev.firebird, connectionTimeout: parseInt(e.target.value) || 30 }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  <div className="md:col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Ruta de Base de Datos
                    </label>
                    <input
                      type="text"
                      value={databaseConfig.firebird.database || ''}
                      onChange={(e) => {
                        const dbPath = e.target.value;
                        setDatabaseConfig(prev => ({
                          ...prev,
                          firebird: { ...prev.firebird, database: dbPath }
                        }));
                        setPathConfig(prev => ({ ...prev, localDbPath: dbPath }));
                      }}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Ruta completa del archivo de base de datos local"
                      readOnly
                    />
                    <p className="text-xs text-gray-500 mt-1">
                      Esta ruta se actualiza automaticamente cuando selecciona el directorio local arriba
                    </p>
                  </div>
                </div>
              </div>

              {/* Configuracion MySQL */}
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4 flex items-center">
                  <Server className="w-5 h-5 mr-2" />
                  Configuracion MySQL
                </h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Host</label>
                    <input
                      type="text"
                      value={databaseConfig.mysql.host}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, host: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="localhost"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Puerto</label>
                    <input
                      type="text"
                      value={databaseConfig.mysql.port}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, port: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="3306"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Base de Datos</label>
                    <input
                      type="text"
                      value={databaseConfig.mysql.database}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, database: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="vigencias_db"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Usuario</label>
                    <input
                      type="text"
                      value={databaseConfig.mysql.user}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, user: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="root"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Contrasena</label>
                    <input
                      type="password"
                      value={databaseConfig.mysql.password}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, password: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="Contrasena MySQL"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Charset</label>
                    <select
                      value={databaseConfig.mysql.charset || 'utf8mb4'}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, charset: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="utf8mb4">utf8mb4 (Recomendado)</option>
                      <option value="utf8">utf8</option>
                      <option value="latin1">latin1</option>
                      <option value="ascii">ascii</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Collation</label>
                    <select
                      value={databaseConfig.mysql.collation || 'utf8mb4_unicode_ci'}
                      onChange={(e) => setDatabaseConfig(prev => ({
                        ...prev,
                        mysql: { ...prev.mysql, collation: e.target.value }
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    >
                      <option value="utf8mb4_unicode_ci">utf8mb4_unicode_ci (Recomendado)</option>
                      <option value="utf8mb4_general_ci">utf8mb4_general_ci</option>
                      <option value="utf8_general_ci">utf8_general_ci</option>
                      <option value="utf8_unicode_ci">utf8_unicode_ci</option>
                      <option value="latin1_swedish_ci">latin1_swedish_ci</option>
                    </select>
                  </div>

                  <div className="md:col-span-2">
                    <div className="flex items-center mb-4">
                      <input
                        type="checkbox"
                        checked={databaseConfig.mysql.sslEnabled || false}
                        onChange={(e) => setDatabaseConfig(prev => ({
                          ...prev,
                          mysql: { ...prev.mysql, sslEnabled: e.target.checked }
                        }))}
                        className="mr-2"
                      />
                      <label className="text-sm font-medium text-gray-700">
                        Habilitar SSL/TLS
                      </label>
                    </div>

                    {databaseConfig.mysql.sslEnabled && (
                      <div className="space-y-4 bg-gray-50 p-4 rounded-lg">
                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Modo SSL</label>
                          <select
                            value={databaseConfig.mysql.sslMode || 'PREFERRED'}
                            onChange={(e) => setDatabaseConfig(prev => ({
                              ...prev,
                              mysql: { ...prev.mysql, sslMode: e.target.value }
                            }))}
                            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                          >
                            <option value="PREFERRED">PREFERRED (Recomendado)</option>
                            <option value="REQUIRED">REQUIRED</option>
                            <option value="DISABLED">DISABLED</option>
                            <option value="VERIFY_CA">VERIFY_CA</option>
                            <option value="VERIFY_IDENTITY">VERIFY_IDENTITY</option>
                          </select>
                        </div>

                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Certificado SSL</label>
                          <div className="flex">
                            <input
                              type="text"
                              value={databaseConfig.mysql.sslCertPath || ''}
                              onChange={(e) => setDatabaseConfig(prev => ({
                                ...prev,
                                mysql: { ...prev.mysql, sslCertPath: e.target.value }
                              }))}
                              className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Ruta del certificado SSL (.pem, .crt)"
                            />
                            <button
                              onClick={() => selectPath('sslCert')}
                              className="px-4 py-2 bg-blue-600 text-white rounded-r-md hover:bg-blue-700 transition-colors"
                            >
                              Buscar
                            </button>
                          </div>
                        </div>

                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Clave Privada SSL</label>
                          <div className="flex">
                            <input
                              type="text"
                              value={databaseConfig.mysql.sslKeyPath || ''}
                              onChange={(e) => setDatabaseConfig(prev => ({
                                ...prev,
                                mysql: { ...prev.mysql, sslKeyPath: e.target.value }
                              }))}
                              className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Ruta de la clave privada SSL (.key, .pem)"
                            />
                            <button
                              onClick={() => selectPath('sslKey')}
                              className="px-4 py-2 bg-blue-600 text-white rounded-r-md hover:bg-blue-700 transition-colors"
                            >
                              Buscar
                            </button>
                          </div>
                        </div>

                        <div>
                          <label className="block text-sm font-medium text-gray-700 mb-2">Certificado CA</label>
                          <div className="flex">
                            <input
                              type="text"
                              value={databaseConfig.mysql.sslCAPath || ''}
                              onChange={(e) => setDatabaseConfig(prev => ({
                                ...prev,
                                mysql: { ...prev.mysql, sslCAPath: e.target.value }
                              }))}
                              className="flex-1 px-3 py-2 border border-gray-300 rounded-l-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Ruta del certificado CA (.pem, .crt)"
                            />
                            <button
                              onClick={() => selectPath('sslCA')}
                              className="px-4 py-2 bg-blue-600 text-white rounded-r-md hover:bg-blue-700 transition-colors"
                            >
                              Buscar
                            </button>
                          </div>
                        </div>
                      </div>
                    )}
                  </div>
                </div>
              </div>

              <div className="flex justify-end space-x-4">
                <button
                  onClick={saveConfiguration}
                  className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors flex items-center"
                >
                  <Shield className="w-4 h-4 mr-2" />
                  Guardar Configuracion
                </button>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'parameters' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-md p-6">
              <h2 className="text-xl font-semibold text-gray-800 mb-6 flex items-center">
                <Settings className="w-6 h-6 mr-2" />
                Parametros de Proceso
              </h2>
              
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4">Configuracion de Consulta</h3>
                <div className="bg-blue-50 p-4 rounded-lg">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={processConfig.todosIdsae}
                      onChange={(e) => setProcessConfig(prev => ({
                        ...prev,
                        todosIdsae: e.target.checked
                      }))}
                      className="mr-3 h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                    <div>
                      <span className="text-sm font-medium text-gray-700">
                        {processConfig.todosIdsae ? 'Todos los IDSAE' : 'Solo IDSAE Procesados'}
                      </span>
                      <p className="text-xs text-gray-600 mt-1">
                        {processConfig.todosIdsae 
                          ? 'Consulta todos los IDSAE de la base remota MySQL con vigencia mayor a la fecha actual'
                          : 'Consulta solo los IDSAE procesados con filtros de vigencias calculadas (comportamiento actual)'
                        }
                      </p>
                    </div>
                  </label>
                </div>
              </div>

              {/* Parametros Generales */}
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4">Parametros Generales</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Dias de Facturas a Procesar
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="30"
                      value={processConfig.diasFacturas}
                      onChange={(e) => setProcessConfig(prev => ({
                        ...prev,
                        diasFacturas: parseInt(e.target.value) || 5
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Dia de Vigencia (1-28)
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="28"
                      value={processConfig.vigenciaDia}
                      onChange={(e) => setProcessConfig(prev => ({
                        ...prev,
                        vigenciaDia: parseInt(e.target.value) || 9
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Vigencia Convenio (dias)
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="365"
                      value={processConfig.vigenciaConvenio}
                      onChange={(e) => setProcessConfig(prev => ({
                        ...prev,
                        vigenciaConvenio: parseInt(e.target.value) || 35
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Vigencia Ciclo Escolar (dias)
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="730"
                      value={processConfig.vigenciaCicloEscolar}
                      onChange={(e) => setProcessConfig(prev => ({
                        ...prev,
                        vigenciaCicloEscolar: parseInt(e.target.value) || 365
                      }))}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    />
                  </div>
                </div>
              </div>

              {/* Palabras de Control */}
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4">Palabras de Control</h3>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Palabras Excluidas (separadas por coma)
                    </label>
                    <textarea
                      value={rawPalabrasExcluidasInput}
                      onChange={(e) => setRawPalabrasExcluidasInput(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      rows={3}
                      placeholder="FONDO DE RESERVA, FONDO, INSCRIP"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Palabras Convenio (separadas por coma)
                    </label>
                    <input
                      type="text"
                      value={rawPalabrasConvenioInput}
                      onChange={(e) => setRawPalabrasConvenioInput(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="CONVENIO"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">
                      Palabras Ciclo Escolar (separadas por coma)
                    </label>
                    <input
                      type="text"
                      value={rawPalabrasCicloEscolarInput}
                      onChange={(e) => setRawPalabrasCicloEscolarInput(e.target.value)}
                      className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                      placeholder="CICLO ESCOLAR"
                    />
                  </div>
                </div>
              </div>

              {/* Programacion Automatica */}
              <div className="mb-8">
                <h3 className="text-lg font-medium text-gray-700 mb-4 flex items-center">
                  <Calendar className="w-5 h-5 mr-2" />
                  Programacion Automatica
                </h3>
                <div className="mb-4">
                  <label className="flex items-center">
                    <input
                      type="checkbox"
                      checked={processConfig.scheduledExecution.enabled}
                      onChange={toggleScheduler}
                      className="mr-2"
                    />
                    <span className="text-sm font-medium text-gray-700">
                      Habilitar ejecucion automatica
                    </span>
                  </label>
                </div>

                {processConfig.scheduledExecution.enabled && (
                  <div className="space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Horarios (formato HH:MM, separados por coma)
                      </label>
                      <input
                        type="text"
                        value={processConfig.scheduledExecution.times.join(', ')}
                        onChange={(e) => {
                          const times = e.target.value.split(',').map(t => t.trim()).filter(t => t);
                          setProcessConfig(prev => ({
                            ...prev,
                            scheduledExecution: {
                              ...prev.scheduledExecution,
                              times
                            }
                          }));
                        }}
                        className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="09:00, 14:00, 18:00"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-2">
                        Dias de la semana
                      </label>
                      <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                        {[
                          { key: 'monday', label: 'Lunes' },
                          { key: 'tuesday', label: 'Martes' },
                          { key: 'wednesday', label: 'Miercoles' },
                          { key: 'thursday', label: 'Jueves' },
                          { key: 'friday', label: 'Viernes' },
                          { key: 'saturday', label: 'Sabado' },
                          { key: 'sunday', label: 'Domingo' }
                        ].map(day => (
                          <label key={day.key} className="flex items-center">
                            <input
                              type="checkbox"
                              checked={processConfig.scheduledExecution.days.includes(day.key)}
                              onChange={(e) => {
                                const updatedDays = e.target.checked
                                  ? [...processConfig.scheduledExecution.days, day.key]
                                  : processConfig.scheduledExecution.days.filter(d => d !== day.key);
                                setProcessConfig(prev => ({
                                  ...prev,
                                  scheduledExecution: {
                                    ...prev.scheduledExecution,
                                    days: updatedDays
                                  }
                                }));
                              }}
                              className="mr-2"
                            />
                            <span className="text-sm text-gray-700">{day.label}</span>
                          </label>
                        ))}
                      </div>
                    </div>
                  </div>
                )}
              </div>

              <div className="flex justify-end space-x-4">
                <button
                  onClick={saveParametersWithProcessing}
                  className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors flex items-center"
                >
                  <Shield className="w-4 h-4 mr-2" />
                  Guardar Parametros
                </button>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'monitor' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-md p-6">
              <h2 className="text-xl font-semibold text-gray-800 mb-6 flex items-center">
                <FileText className="w-6 h-6 mr-2" />
                Monitor del Sistema
              </h2>

              {/* Process Status */}
              <div className="mb-6">
                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="font-medium text-gray-800">Estado del Proceso</h3>
                      <p className="text-sm text-gray-600">
                        {processStatus.isRunning ? `Ejecutando: ${processStatus.currentStep}` : 'Inactivo'}
                      </p>
                    </div>
                    <div className="text-right">
                      {processStatus.isRunning ? (
                        <div className="flex items-center text-blue-600">
                          <Monitor className="w-5 h-5 mr-2 animate-pulse" />
                          <span>En proceso</span>
                        </div>
                      ) : (
                        <div className="flex items-center text-green-600">
                          <CheckCircle className="w-5 h-5 mr-2" />
                          <span>Listo</span>
                        </div>
                      )}
                    </div>
                  </div>
                  
                  {processStatus.isRunning && (
                    <div className="mt-4">
                      <div className="w-full bg-gray-200 rounded-full h-2">
                        <div 
                          className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                          style={{ width: `${processStatus.progress}%` }}
                        ></div>
                      </div>
                      <p className="text-xs text-gray-500 mt-1">
                        {processStatus.progress}% completado
                      </p>
                    </div>
                  )}
                </div>
              </div>

              {/* Scheduler Status */}
              {processConfig.scheduledExecution.enabled && (
                <div className="mb-6">
                  <h3 className="font-medium text-gray-800 mb-3">Programacion Activa</h3>
                  <div className="bg-blue-50 rounded-lg p-4">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div>
                        <p className="text-sm font-medium text-blue-800">Horarios</p>
                        <p className="text-sm text-blue-600">{processConfig.scheduledExecution.times.join(', ')}</p>
                      </div>
                      <div>
                        <p className="text-sm font-medium text-blue-800">Dias</p>
                        <p className="text-sm text-blue-600">
                          {processConfig.scheduledExecution.days.map(day => ({
                            monday: 'Lun', tuesday: 'Mar', wednesday: 'Mie', thursday: 'Jue',
                            friday: 'Vie', saturday: 'Sab', sunday: 'Dom'
                          }[day])).join(', ')}
                        </p>
                      </div>
                    </div>
                    {processConfig.scheduledExecution.lastExecution && (
                      <div className="mt-3 pt-3 border-t border-blue-200">
                        <p className="text-sm text-blue-600">
                          Ultima ejecucion: {new Date(processConfig.scheduledExecution.lastExecution).toLocaleString('es-ES')}
                        </p>
                      </div>
                    )}
                  </div>
                </div>
              )}
            </div>
          </div>
        )}

        {activeTab === 'logs' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-md p-6">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-gray-800 flex items-center">
                  <Activity className="w-6 h-6 mr-2" />
                  Registro de Actividad
                </h2>
                <button
                  onClick={() => setLogs([])}
                  className="px-4 py-2 text-sm bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-md transition-colors"
                >
                  Limpiar Logs
                </button>
              </div>

              <div className="space-y-2 max-h-96 overflow-y-auto">
                {logs.map(log => (
                  <div key={log.id} className="flex items-start space-x-3 p-3 rounded-lg bg-gray-50 hover:bg-gray-100 transition-colors">
                    <div className="flex-shrink-0 mt-1">
                      {log.status === 'success' && <CheckCircle className="w-5 h-5 text-green-600" />}
                      {log.status === 'error' && <XCircle className="w-5 h-5 text-red-600" />}
                      {log.status === 'warning' && <AlertCircle className="w-5 h-5 text-yellow-600" />}
                      {log.status === 'info' && <AlertCircle className="w-5 h-5 text-blue-600" />}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-gray-800 font-medium">{log.message}</p>
                      <div className="flex items-center space-x-4 mt-1">
                        <p className="text-xs text-gray-500">
                          {new Date(log.timestamp).toLocaleString('es-ES')}
                        </p>
                        <p className="text-xs text-gray-500">{log.process}</p>
                      </div>
                    </div>
                  </div>
                ))}
                {logs.length === 0 && (
                  <div className="text-center py-8">
                    <Activity className="w-12 h-12 text-gray-300 mx-auto mb-4" />
                    <p className="text-gray-500">No hay registros de actividad</p>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
};

export default App;