export interface ElectronAPI {
  selectFile: (options?: any) => Promise<string | null>;
  selectDirectory: () => Promise<string | null>;
  readConfig: () => Promise<any>;
  saveConfig: (config: any) => Promise<void>;
  
  // Funciones de autenticación
  registerUser: (data: { username: string; password: string }) => Promise<{ success: boolean; error?: string }>;
  loginUser: (data: { username: string; password: string }) => Promise<{ success: boolean; error?: string }>;
  checkUserExists: () => Promise<{ exists: boolean }>;
  savePowershellConfig: (data: any) => Promise<{ success: boolean; error?: string }>;
  
  copyDatabase: (source: string, destination: string) => Promise<DatabaseOperationResult>;
  syncClientes: () => Promise<ConnectionResult>;
  exportRegistros: (outputPath: string, diasRevision: number) => Promise<ConnectionResult>;
  processVigencias: (config: ProcessConfig, paths: PathConfig, dbConfig: DatabaseConfig) => Promise<ProcessResult>;
  testFirebirdConnection: (config: FirebirdConfig) => Promise<ConnectionResult>;
  testMySQLConnection: (config: MySQLConfig) => Promise<ConnectionResult>;
}

export interface BridgeAPI {
  copyDatabase: (source: string, destination: string) => Promise<DatabaseOperationResult>;
  syncClientes: () => Promise<ConnectionResult>;
  exportRegistros: (outputPath: string, diasRevision: number) => Promise<ConnectionResult>;
  processVigencias: (config: ProcessConfig, paths: PathConfig, dbConfig: DatabaseConfig) => Promise<ProcessResult>;
  testFirebird: (config: FirebirdConfig) => Promise<ConnectionResult>;
  testMySQL: (config: MySQLConfig) => Promise<ConnectionResult>;
}
export interface DatabaseConfig {
  firebird: FirebirdConfig;
  mysql: MySQLConfig;
}

export interface FirebirdConfig {
  host: string;
  database: string;
  user: string;
  password: string;
  port: string;
  clientCharset: string;
  dialect: number;
  odbcDriverName?: string;
  connectionTimeout?: number;
  clientCharset: string;
  dialect: number;
  odbcDriverName?: string;
  connectionTimeout?: number;
}

export interface MySQLConfig {
  host: string;
  port: string;
  database: string;
  user: string;
  password: string;
  charset?: string;
  collation?: string;
  sslEnabled?: boolean;
  sslMode?: string;
  sslCertPath?: string;
  sslKeyPath?: string;
  sslCAPath?: string;
  charset?: string;
  collation?: string;
  sslEnabled?: boolean;
  sslMode?: string;
  sslCertPath?: string;
  sslKeyPath?: string;
  sslCAPath?: string;
}

export interface PathConfig {
  sourceDbPath: string;
  localDbPath: string;
  outputPath: string;
}

export interface ProcessConfig {
  diasFacturas: number;
  vigenciaDia: number;
  vigenciaConvenio: number;
  vigenciaCicloEscolar: number;
  palabrasExcluidas: string[];
  palabrasConvenio: string[];
  palabrasCicloEscolar: string[];
  todosIdsae: boolean;
  scheduledExecution: {
    enabled: boolean;
    times: string[];
    days: string[];
    lastExecution: string | null;
  };
}

export interface ProcessLog {
  id: string;
  timestamp: string;
  process: string;
  message: string;
  status: 'success' | 'error' | 'warning' | 'info';
}

export interface ProcessStatus {
  isRunning: boolean;
  currentStep: string;
  progress: number;
  lastRun: string | null;
}

export interface ProcessResult {
  success: boolean;
  message: string;
  facturasProcessed: number;
  vigenciasUpdated: number;
  registrosGenerados: number;
  errors: string[];
  archivosGenerados: string[];
}

export interface ConnectionResult {
  success: boolean;
  message?: string;
  error?: string;
}

export interface DatabaseOperationResult {
  success: boolean;
  message?: string;
  error?: string;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
    bridge?: BridgeAPI;
  }
}