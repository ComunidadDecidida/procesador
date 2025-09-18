import { ProcessConfig } from '../types';

let executionInProgress = false;

class SchedulerService {
  private intervalId: NodeJS.Timeout | null = null;
  private lastExecutionTime: string | null = null;
  private onExecute: (() => Promise<void>) | null = null;

  /**
   * Obtiene la hora actual de CDMX Mexico
   */
  private getCdmxTime(): Date {
    try {
      const now = new Date();
      // Usar Intl.DateTimeFormat para obtener hora precisa de CDMX
      const formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'America/Mexico_City',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false
      });
      
      const parts = formatter.formatToParts(now);
      const year = parseInt(parts.find(p => p.type === 'year')?.value || '2025');
      const month = parseInt(parts.find(p => p.type === 'month')?.value || '1') - 1;
      const day = parseInt(parts.find(p => p.type === 'day')?.value || '1');
      const hour = parseInt(parts.find(p => p.type === 'hour')?.value || '0');
      const minute = parseInt(parts.find(p => p.type === 'minute')?.value || '0');
      const second = parseInt(parts.find(p => p.type === 'second')?.value || '0');
      
      return new Date(year, month, day, hour, minute, second);
    } catch (error) {
      console.warn('Error obteniendo hora CDMX, usando hora local:', error);
      return new Date();
    }
  }

  /**
   * Inicia el planificador con verificacion cada 30 segundos
   */
  startScheduler(config: ProcessConfig, onExecute: () => Promise<void>) {
    this.stopScheduler();
    
    if (!config.scheduledExecution.enabled) {
      console.log('Scheduler deshabilitado en configuracion');
      return;
    }

    this.onExecute = onExecute;

    // Verificar cada 30 segundos para mayor precision
    this.intervalId = setInterval(() => {
      this.checkAndExecute(config);
    }, 30000);

    const cdmxTime = this.getCdmxTime();
    console.log('=== SCHEDULER INICIADO ===');
    console.log('Hora CDMX actual:', cdmxTime.toLocaleString('es-MX'));
    console.log('Horarios configurados:', config.scheduledExecution.times);
    console.log('Dias configurados:', config.scheduledExecution.days);
    console.log('Verificacion cada 30 segundos');
    console.log('========================');
  }

  /**
   * Detiene el planificador
   */
  stopScheduler() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      console.log('Scheduler detenido correctamente');
    }
  }

  /**
   * Verifica si debe ejecutar segun horarios programados
   */
  private async checkAndExecute(config: ProcessConfig) {
    try {
      const cdmxTime = this.getCdmxTime();
      
      // Formato HH:MM para comparacion
      const currentTime = `${cdmxTime.getHours().toString().padStart(2, '0')}:${cdmxTime.getMinutes().toString().padStart(2, '0')}`;
      const currentDay = this.getDayName(cdmxTime.getDay());
      
      // Clave unica para evitar ejecuciones duplicadas
      const executionKey = `${cdmxTime.getFullYear()}-${(cdmxTime.getMonth() + 1).toString().padStart(2, '0')}-${cdmxTime.getDate().toString().padStart(2, '0')}_${currentTime}`;

      // Log cada minuto para debug
      if (cdmxTime.getSeconds() >= 0 && cdmxTime.getSeconds() <= 30) {
        console.log(`[SCHEDULER] Verificando: ${currentTime} - ${currentDay} (${cdmxTime.toLocaleString('es-MX')})`);
        console.log(`[SCHEDULER] Buscando en horarios: ${config.scheduledExecution.times.join(', ')}`);
        console.log(`[SCHEDULER] Buscando en dias: ${config.scheduledExecution.days.join(', ')}`);
      }

      // Verificar si es hora de ejecutar
      const shouldExecute = config.scheduledExecution.times.includes(currentTime) && 
                           config.scheduledExecution.days.includes(currentDay);

      if (shouldExecute) {
        console.log(`[SCHEDULER] ¡COINCIDENCIA ENCONTRADA! ${currentTime} en ${currentDay}`);
        
        if (executionInProgress) {
          console.log('[SCHEDULER] Ejecucion ya en progreso, omitiendo...');
          return;
        }

        // Evitar ejecuciones duplicadas
        if (this.lastExecutionTime === executionKey) {
          console.log('[SCHEDULER] Ya ejecutado en este minuto, omitiendo...');
          return;
        }

        // EJECUTAR PROCESO
        this.lastExecutionTime = executionKey;
        config.scheduledExecution.lastExecution = cdmxTime.toISOString();

        console.log(`[SCHEDULER] *** INICIANDO EJECUCION PROGRAMADA ***`);
        console.log(`[SCHEDULER] Hora: ${currentTime} CDMX`);
        console.log(`[SCHEDULER] Dia: ${currentDay}`);
        console.log(`[SCHEDULER] Fecha completa: ${cdmxTime.toLocaleString('es-MX')}`);
        
        executionInProgress = true;
        
        try {
          await this.runScheduledTasks();
          console.log(`[SCHEDULER] *** EJECUCION COMPLETADA EXITOSAMENTE ***`);
        } catch (error) {
          console.error(`[SCHEDULER] *** ERROR EN EJECUCION PROGRAMADA ***`, error);
        } finally {
          executionInProgress = false;
        }
      }
    } catch (error) {
      console.error('[SCHEDULER] Error en verificacion:', error);
    }
  }

  /**
   * Ejecuta las tareas programadas
   */
  private async runScheduledTasks() {
    try {
      const startTime = this.getCdmxTime();
      console.log(`[SCHEDULER] Iniciando flujo programado: ${startTime.toLocaleString('es-MX')}`);
      
      if (!this.onExecute) {
        throw new Error('Callback onExecute no definido');
      }
      
      await this.onExecute();
      
      const endTime = this.getCdmxTime();
      const duration = endTime.getTime() - startTime.getTime();
      console.log(`[SCHEDULER] Flujo completado en ${duration}ms: ${endTime.toLocaleString('es-MX')}`);
    } catch (error) {
      const errorTime = this.getCdmxTime();
      console.error(`[SCHEDULER] Error en flujo programado ${errorTime.toLocaleString('es-MX')}:`, error);
      throw error;
    }
  }

  /**
   * Convierte indice de dia a nombre en ingles
   */
  private getDayName(dayIndex: number): string {
    const days = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    return days[dayIndex];
  }

  /**
   * Calcula la proxima ejecucion programada
   */
  getNextExecution(config: ProcessConfig): Date | null {
    if (!config.scheduledExecution.enabled) return null;
    
    try {
      const cdmxNow = this.getCdmxTime();
      
      // Buscar en los proximos 7 dias
      for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
        const checkDate = new Date(cdmxNow);
        checkDate.setDate(checkDate.getDate() + dayOffset);
        
        const dayName = this.getDayName(checkDate.getDay());
        
        if (config.scheduledExecution.days.includes(dayName)) {
          for (const timeStr of config.scheduledExecution.times.sort()) {
            const [hours, minutes] = timeStr.split(':').map(Number);
            const executionTime = new Date(checkDate);
            executionTime.setHours(hours, minutes, 0, 0);
            
            // Si es hoy, verificar que no haya pasado
            if (dayOffset === 0 && executionTime <= cdmxNow) {
              continue;
            }
            
            return executionTime;
          }
        }
      }
      
      return null;
    } catch (error) {
      console.error('Error calculando proxima ejecucion:', error);
      return null;
    }
  }

  /**
   * Formatea la proxima ejecucion
   */
  formatNextExecution(config: ProcessConfig): string {
    const nextExecution = this.getNextExecution(config);
    if (!nextExecution) return 'No programado';
    
    return nextExecution.toLocaleString('es-MX', {
      timeZone: 'America/Mexico_City',
      weekday: 'long', 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric',
      hour: '2-digit', 
      minute: '2-digit'
    });
  }

  /**
   * Obtiene el estado actual del scheduler
   */
  getSchedulerStatus(config: ProcessConfig) {
    const cdmxTime = this.getCdmxTime();
    
    return {
      enabled: config.scheduledExecution.enabled,
      currentTime: cdmxTime.toLocaleTimeString('es-MX', { 
        timeZone: 'America/Mexico_City',
        hour12: false 
      }),
      currentDateTime: cdmxTime.toLocaleString('es-MX', {
        timeZone: 'America/Mexico_City'
      }),
      nextExecution: this.formatNextExecution(config),
      executionInProgress: executionInProgress,
      configuredTimes: config.scheduledExecution.times,
      configuredDays: config.scheduledExecution.days,
      lastExecution: config.scheduledExecution.lastExecution,
      intervalActive: this.intervalId !== null
    };
  }

  /**
   * Verifica si hay una ejecucion en progreso
   */
  isExecutionInProgress(): boolean {
    return executionInProgress;
  }

  /**
   * Fuerza una verificacion manual (para testing)
   */
  async forceCheck(config: ProcessConfig) {
    console.log('[SCHEDULER] Verificacion manual forzada');
    await this.checkAndExecute(config);
  }

  /**
   * Reinicia el scheduler cuando cambian configuraciones
   */
  restartScheduler(config: ProcessConfig, onExecute: () => Promise<void>) {
    console.log('[SCHEDULER] Reiniciando scheduler por cambio de configuracion');
    this.stopScheduler();
    if (config.scheduledExecution.enabled) {
      this.startScheduler(config, onExecute);
    }
  }
}

export const schedulerService = new SchedulerService();