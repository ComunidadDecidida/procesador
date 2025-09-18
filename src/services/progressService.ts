import { ProcessLog } from '../types';

class ProgressService {
  private progressCallbacks: ((progress: number, step: string) => void)[] = [];
  private currentProgress: number = 0;
  private processedMessages: Set<string> = new Set();
  
  // Mapeo secuencial de progreso - solo avanza, nunca retrocede
  private progressStages = [
    { keywords: ['iniciando proceso', 'proceso iniciado'], progress: 5, step: 'Iniciando proceso' },
    { keywords: ['validando configuracion'], progress: 8, step: 'Validando configuracion' },
    { keywords: ['copiando base de datos', 'copia de base de datos'], progress: 15, step: 'Copiando base de datos' },
    { keywords: ['archivo copiado', 'base de datos copiada', 'copia exitosa'], progress: 25, step: 'Base de datos copiada' },
    { keywords: ['sincronizando clientes', 'sincronizacion de clientes'], progress: 35, step: 'Sincronizando clientes' },
    { keywords: ['conectando a mysql'], progress: 40, step: 'Conectando a MySQL' },
    { keywords: ['clientes sincronizados', 'sincronizacion exitosa'], progress: 45, step: 'Clientes sincronizados' },
    { keywords: ['procesando facturas', 'procesamiento de facturas'], progress: 50, step: 'Procesando facturas' },
    { keywords: ['leyendo facturas', 'facturas leidas'], progress: 60, step: 'Analizando facturas' },
    { keywords: ['facturas procesadas', 'procesamiento exitoso'], progress: 70, step: 'Facturas procesadas' },
    { keywords: ['calculando vigencias', 'calculo de vigencias'], progress: 75, step: 'Calculando vigencias' },
    { keywords: ['aplicando reglas'], progress: 80, step: 'Aplicando reglas de negocio' },
    { keywords: ['vigencias calculadas', 'actualizando vigencias'], progress: 85, step: 'Actualizando vigencias' },
    { keywords: ['vigencias actualizadas'], progress: 90, step: 'Vigencias actualizadas' },
    { keywords: ['exportando registros', 'exportacion de registros'], progress: 93, step: 'Exportando registros' },
    { keywords: ['generando archivos'], progress: 96, step: 'Generando archivos' },
    { keywords: ['registros exportados', 'exportacion exitosa'], progress: 98, step: 'Registros exportados' },
    { keywords: ['proceso completado', 'proceso exitoso', 'completado exitosamente'], progress: 100, step: 'Proceso completado' }
  ];

  onProgress(callback: (progress: number, step: string) => void) {
    this.progressCallbacks.push(callback);
  }

  removeProgressCallback(callback: (progress: number, step: string) => void) {
    this.progressCallbacks = this.progressCallbacks.filter(cb => cb !== callback);
  }

  updateProgress(logEntry: ProcessLog) {
    const message = logEntry.message.toLowerCase();
    const messageKey = `${message}_${logEntry.timestamp}`;
    
    // Evitar procesar el mismo mensaje multiple veces
    if (this.processedMessages.has(messageKey)) {
      return;
    }
    
    this.processedMessages.add(messageKey);
    
    // Buscar la etapa correspondiente al mensaje
    for (const stage of this.progressStages) {
      const matchesKeyword = stage.keywords.some(keyword => 
        message.includes(keyword.toLowerCase())
      );
      
      if (matchesKeyword) {
        // Solo avanzar si el nuevo progreso es mayor al actual
        if (stage.progress > this.currentProgress) {
          this.currentProgress = stage.progress;
          this.notifyProgress(stage.progress, stage.step);
          console.log(`[PROGRESS] Avanzando a ${stage.progress}% - ${stage.step}`);
          return;
        } else {
          console.log(`[PROGRESS] Ignorando retroceso: ${stage.progress}% <= ${this.currentProgress}%`);
          return;
        }
      }
    }
    
    // Buscar patrones numericos solo si no hay coincidencia de etapa
    this.handleNumericProgress(message);
  }

  private handleNumericProgress(message: string) {
    // Buscar patrones numericos para progreso dinamico (solo si mejora el progreso actual)
    const numberMatch = message.match(/(\d+)\s*(facturas?|vigencias?|registros?|clientes?)/);
    if (numberMatch) {
      const count = parseInt(numberMatch[1]);
      const type = numberMatch[2];
      let calculatedProgress = this.currentProgress;
      let step = '';
      
      if (type === 'facturas' && count > 0 && this.currentProgress >= 50 && this.currentProgress < 70) {
        calculatedProgress = Math.min(69, 50 + Math.floor(count / 50));
        step = `${count} facturas procesadas`;
      } else if (type === 'vigencias' && count > 0 && this.currentProgress >= 75 && this.currentProgress < 90) {
        calculatedProgress = Math.min(89, 75 + Math.floor(count / 100));
        step = `${count} vigencias actualizadas`;
      } else if (type === 'registros' && count > 0 && this.currentProgress >= 93 && this.currentProgress < 98) {
        calculatedProgress = Math.min(97, 93 + Math.floor(count / 200));
        step = `${count} registros generados`;
      } else if (type === 'clientes' && count > 0 && this.currentProgress >= 35 && this.currentProgress < 45) {
        calculatedProgress = Math.min(44, 35 + Math.floor(count / 200));
        step = `${count} clientes sincronizados`;
      }
      
      // Solo actualizar si hay mejora
      if (calculatedProgress > this.currentProgress && step) {
        this.currentProgress = calculatedProgress;
        this.notifyProgress(calculatedProgress, step);
        console.log(`[PROGRESS] Progreso numerico: ${calculatedProgress}% - ${step}`);
      }
    }
    
    // Buscar patrones de porcentaje explícito
    const percentMatch = message.match(/(\d+)%/);
    if (percentMatch) {
      const percent = parseInt(percentMatch[1]);
      if (percent >= 0 && percent <= 100 && percent > this.currentProgress) {
        this.currentProgress = percent;
        this.notifyProgress(percent, `${percent}% completado`);
        console.log(`[PROGRESS] Porcentaje explícito: ${percent}%`);
      }
    }
  }

  private notifyProgress(progress: number, step: string) {
    this.progressCallbacks.forEach(callback => {
      try {
        callback(progress, step);
      } catch (error) {
        console.error('Error en callback de progreso:', error);
      }
    });
  }

  reset() {
    this.currentProgress = 0;
    this.processedMessages.clear();
    this.notifyProgress(0, 'Preparando...');
    console.log('[PROGRESS] Progreso reiniciado');
  }

  complete() {
    this.currentProgress = 100;
    this.notifyProgress(100, 'Proceso completado');
    console.log('[PROGRESS] Proceso completado al 100%');
  }

  getCurrentProgress(): number {
    return this.currentProgress;
  }
}

export const progressService = new ProgressService();