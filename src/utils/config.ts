import { DatabaseConfig, PathConfig, ProcessConfig } from '../types';

export interface AppConfig {
  database: DatabaseConfig;
  paths: PathConfig;
  process: ProcessConfig;
  lastUpdated: string;
}

const DEFAULT_CONFIG: AppConfig = {
  database: {
    firebird: {
      host: 'localhost',
      database: 'C:\\Users\\LENOVO AIO PC\\Desktop\\SAE90EMPRE01_local.FDB',
      user: 'SYSDBA',
      password: 'masterkey',
      port: '3050',
      clientCharset: 'WIN1252',
      dialect: 3,
      odbcDriverName: 'Firebird/InterBase(r) driver',
      connectionTimeout: 30
    },
    mysql: {
      host: 'bdjhon.chyuseqm2ltf.us-east-2.rds.amazonaws.com',
      port: '3306',
      database: 'ComunidadDecidida',
      user: 'admin',
      password: 'Peaky*50',
      charset: 'utf8mb4',
      collation: 'utf8mb4_unicode_ci',
      sslEnabled: true,
      sslMode: 'PREFERRED',
      sslCertPath: '',
      sslKeyPath: '',
      sslCAPath: ''
    }
  },
  paths: {
    sourceDbPath: 'C:\\Users\\LENOVO AIO PC\\Downloads\\SAE90EMPRE01\\SAE90EMPRE01.FDB',
    localDbPath: 'C:\\Users\\LENOVO AIO PC\\Desktop\\SAE90EMPRE01_local.FDB',
    outputPath: 'C:\\Users\\LENOVO AIO PC\\Desktop\\pruebas de archivos\\'
  },
  process: {
    diasFacturas: 5,
    vigenciaDia: 9,
    vigenciaConvenio: 35,
    vigenciaCicloEscolar: 365,
    palabrasExcluidas: ['FONDO DE RESERVA', 'FONDO', 'INSCRIP', 'INSCRIPCION', 'ADELANTO', 'TARJETA', 'TARJE', 'ACCESO', 'TAG', 'APP'],
    palabrasConvenio: ['CONVENIO'],
    palabrasCicloEscolar: ['CICLO ESCOLAR'],
    todosIdsae: false,
    scheduledExecution: {
      enabled: false,
      times: ['09:00'],
      days: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
      lastExecution: null
    }
  },
  lastUpdated: new Date().toISOString()
};

class ConfigManager {
  private isElectron: boolean;

  constructor() {
    this.isElectron = typeof window !== 'undefined' && window.electronAPI !== undefined;
  }

  async loadConfig(): Promise<AppConfig> {
    try {
      if (this.isElectron && window.electronAPI?.readConfig) {
        const config = await window.electronAPI.readConfig();
        return config ? { ...DEFAULT_CONFIG, ...config } : DEFAULT_CONFIG;
      } else {
        const stored = localStorage.getItem('vigencias-config');
        if (stored) {
          const parsed = JSON.parse(stored);
          return { ...DEFAULT_CONFIG, ...parsed };
        }
      }
    } catch (error) {
      console.error('Error loading config:', error);
    }
    return DEFAULT_CONFIG;
  }

  async saveConfig(config: AppConfig): Promise<void> {
    try {
      const configToSave = {
        ...config,
        lastUpdated: new Date().toISOString()
      };

      if (this.isElectron && window.electronAPI?.saveConfig) {
        await window.electronAPI.saveConfig(configToSave);
      } else {
        localStorage.setItem('vigencias-config', JSON.stringify(configToSave));
      }
    } catch (error) {
      console.error('Error saving config:', error);
      throw error;
    }
  }
}

export const configManager = new ConfigManager();