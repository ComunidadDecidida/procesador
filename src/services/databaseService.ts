import { DatabaseConfig, PathConfig, ProcessConfig, ProcessResult, ConnectionResult, DatabaseOperationResult } from '../types';

class DatabaseService {
  private isElectron: boolean;
  private operationInProgress: Set<string> = new Set();

  constructor() {
    this.isElectron = typeof window !== 'undefined' && window.electronAPI !== undefined;
  }

  private async executeWithTimeout<T>(operation: () => Promise<T>, timeoutMs: number = 600000): Promise<T> {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(new Error(`Operación excedió el tiempo límite de ${timeoutMs / 1000} segundos`));
      }, timeoutMs);

      operation()
        .then(result => {
          clearTimeout(timeout);
          resolve(result);
        })
        .catch(error => {
          clearTimeout(timeout);
          reject(error);
        });
    });
  }

  async syncClientes(): Promise<ConnectionResult> {
    try {
      if (this.operationInProgress.has('sync')) {
        return { success: false, error: 'Operación ya en progreso' };
      }
      
      this.operationInProgress.add('sync');
      
      if (this.isElectron && window.electronAPI?.syncClientes) {
        const result = await this.executeWithTimeout(() => window.electronAPI.syncClientes(), 300000);
        return result;
      } else {
        console.warn('Sync clientes not available in web mode');
        return { success: false, error: 'Sincronización de clientes no disponible en modo web' };
      }
    } catch (error) {
      console.error('Sync clientes failed:', error);
      return { success: false, error: error.message };
    } finally {
      this.operationInProgress.delete('sync');
    }
  }

  async exportRegistros(outputPath: string, diasRevision: number): Promise<ConnectionResult> {
    try {
      if (this.operationInProgress.has('export')) {
        return { success: false, error: 'Operación ya en progreso' };
      }
      
      this.operationInProgress.add('export');
      
      if (this.isElectron && window.electronAPI?.exportRegistros) {
        const result = await this.executeWithTimeout(() => window.electronAPI.exportRegistros(outputPath, diasRevision), 180000);
        return result;
      } else {
        console.warn('Export registros not available in web mode');
        return { success: false, error: 'Exportación de registros no disponible en modo web' };
      }
    } catch (error) {
      console.error('Export registros failed:', error);
      return { success: false, error: error.message };
    } finally {
      this.operationInProgress.delete('export');
    }
  }
  async testFirebirdConnection(config: DatabaseConfig['firebird']): Promise<ConnectionResult> {
    try {
      if (this.operationInProgress.has('test-firebird')) {
        return { success: false, error: 'Operación ya en progreso' };
      }
      
      this.operationInProgress.add('test-firebird');
      
      if (this.isElectron && window.electronAPI?.testFirebirdConnection) {
        const result = await this.executeWithTimeout(() => window.electronAPI.testFirebirdConnection(config), 60000);
        return result;
      } else {
        console.warn('Firebird connection not available in web mode');
        return { success: false, error: 'Conexion Firebird no disponible en modo web' };
      }
    } catch (error) {
      console.error('Firebird connection test failed:', error);
      return { success: false, error: error.message };
    } finally {
      this.operationInProgress.delete('test-firebird');
    }
  }

  async testMySQLConnection(config: DatabaseConfig['mysql']): Promise<ConnectionResult> {
    try {
      if (this.operationInProgress.has('test-mysql')) {
        return { success: false, error: 'Operación ya en progreso' };
      }
      
      this.operationInProgress.add('test-mysql');
      
      if (this.isElectron && window.electronAPI?.testMySQLConnection) {
        const result = await this.executeWithTimeout(() => window.electronAPI.testMySQLConnection(config), 60000);
        return result;
      } else {
        console.warn('MySQL connection not available in web mode');
        return { success: false, error: 'Conexion MySQL no disponible en modo web' };
      }
    } catch (error) {
      console.error('MySQL connection test failed:', error);
      return { success: false, error: error.message };
    } finally {
      this.operationInProgress.delete('test-mysql');
    }
  }

  async copyDatabase(sourcePath: string, destinationPath: string): Promise<DatabaseOperationResult> {
    try {
      if (this.operationInProgress.has('copy')) {
        return { success: false, error: 'Operación ya en progreso' };
      }
      
      this.operationInProgress.add('copy');
      
      if (this.isElectron && window.electronAPI?.copyDatabase) {
        const result = await this.executeWithTimeout(() => window.electronAPI.copyDatabase(sourcePath, destinationPath), 900000);
        return result;
      } else {
        console.warn('Database copy not available in web mode');
        return { success: false, error: 'Copia de base de datos no disponible en modo web' };
      }
    } catch (error) {
      console.error('Database copy failed:', error);
      return { success: false, error: error.message };
    } finally {
      this.operationInProgress.delete('copy');
    }
  }

  async processVigencias(
    processConfig: ProcessConfig, 
    pathConfig: PathConfig, 
    dbConfig: DatabaseConfig
  ): Promise<ProcessResult> {
    try {
      if (this.operationInProgress.has('process')) {
        return {
          success: false,
          message: 'Operación ya en progreso',
          facturasProcessed: 0,
          vigenciasUpdated: 0,
          registrosGenerados: 0,
          errors: ['Operación ya en progreso'],
          archivosGenerados: []
        };
      }
      
      this.operationInProgress.add('process');
      
      if (this.isElectron && window.electronAPI?.processVigencias) {
        // TIEMPO AUMENTADO: 45 minutos (2700000ms) para procesos secuenciales con estabilizacion
        const result = await this.executeWithTimeout(() => window.electronAPI.processVigencias(processConfig, pathConfig, dbConfig), 2700000);
        return result;
      } else {
        console.warn('Vigencias processing not available in web mode');
        return {
          success: false,
          message: 'Procesamiento de vigencias no disponible en modo web',
          facturasProcessed: 0,
          vigenciasUpdated: 0,
          registrosGenerados: 0,
          errors: ['Funcionalidad no disponible en modo web'],
          archivosGenerados: []
        };
      }
    } catch (error) {
      console.error('Vigencias processing failed:', error);
      return {
        success: false,
        message: `Error procesando vigencias: ${error.message}`,
        facturasProcessed: 0,
        vigenciasUpdated: 0,
        registrosGenerados: 0,
        errors: [error.message],
        archivosGenerados: []
      };
    } finally {
      this.operationInProgress.delete('process');
    }
  }

  isOperationInProgress(): boolean {
    return this.operationInProgress.size > 0;
  }
  
  isSpecificOperationInProgress(operation: string): boolean {
    return this.operationInProgress.has(operation);
  }
}

export const databaseService = new DatabaseService();