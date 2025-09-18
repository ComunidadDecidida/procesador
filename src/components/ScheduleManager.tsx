import React, { useState } from 'react';
import { Plus, Trash2, Clock, Calendar } from 'lucide-react';
import { ProcessConfig } from '../types';

interface ScheduleManagerProps {
  config: ProcessConfig;
  onConfigChange: (config: ProcessConfig) => void;
}

const ScheduleManager: React.FC<ScheduleManagerProps> = ({ config, onConfigChange }) => {
  const [hour, setHour] = useState(9);
  const [minute, setMinute] = useState(0);
  const [period, setPeriod] = useState<'AM' | 'PM'>('AM');
  const [preview, setPreview] = useState('');
  const [isRestarting, setIsRestarting] = useState(false);

  const daysOfWeek = [
    { key: 'monday', label: 'Lunes' },
    { key: 'tuesday', label: 'Martes' },
    { key: 'wednesday', label: 'Miercoles' },
    { key: 'thursday', label: 'Jueves' },
    { key: 'friday', label: 'Viernes' },
    { key: 'saturday', label: 'Sabado' },
    { key: 'sunday', label: 'Domingo' }
  ];

  const convertTo24h = (h: number, m: number, p: 'AM' | 'PM') => {
    let adjusted = h % 12;
    if (p === 'PM') adjusted += 12;
    return `${adjusted.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`;
  };

  const updatePreview = (h: number, m: number, p: 'AM' | 'PM') => {
    const formatted12h = `${h}:${m.toString().padStart(2, '0')} ${p}`;
    const formatted24h = convertTo24h(h, m, p);
    setPreview(`${formatted12h} (${formatted24h})`);
  };

  const addTime = () => {
    const newTime = convertTo24h(hour, minute, period);
    if (newTime && !config.scheduledExecution.times.includes(newTime)) {
      const updatedConfig = {
        ...config,
        scheduledExecution: {
          ...config.scheduledExecution,
          times: [...config.scheduledExecution.times, newTime].sort()
        }
      };
      onConfigChange(updatedConfig);
      // reinicio visual
      setIsRestarting(true);
      setTimeout(() => setIsRestarting(false), 800);
      setHour(9);
      setMinute(0);
      setPeriod('AM');
      setPreview('');
    }
  };

  const removeTime = (timeToRemove: string) => {
    const updatedConfig = {
      ...config,
      scheduledExecution: {
        ...config.scheduledExecution,
        times: config.scheduledExecution.times.filter(time => time !== timeToRemove)
      }
    };
    onConfigChange(updatedConfig);
  };

  const toggleDay = (dayKey: string) => {
    const updatedDays = config.scheduledExecution.days.includes(dayKey)
      ? config.scheduledExecution.days.filter(day => day !== dayKey)
      : [...config.scheduledExecution.days, dayKey];

    const updatedConfig = {
      ...config,
      scheduledExecution: {
        ...config.scheduledExecution,
        days: updatedDays
      }
    };
    onConfigChange(updatedConfig);
  };

  const toggleEnabled = () => {
    const updatedConfig = {
      ...config,
      scheduledExecution: {
        ...config.scheduledExecution,
        enabled: !config.scheduledExecution.enabled
      }
    };
    onConfigChange(updatedConfig);
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-medium text-gray-700 flex items-center">
          <Calendar className="w-5 h-5 mr-2" />
          Programacion Automatica
        </h3>
        <label className="flex items-center">
          <input
            type="checkbox"
            checked={config.scheduledExecution.enabled}
            onChange={toggleEnabled}
            className="mr-2"
          />
          <span className="text-sm font-medium text-gray-700">Habilitar</span>
        </label>
      </div>

      {config.scheduledExecution.enabled && (
        <div className="space-y-4">
          {/* Horarios */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Horarios de Ejecucion
            </label>
            
            {/* Lista de horarios actuales */}
            <div className="space-y-2 mb-3">
              {config.scheduledExecution.times.map((time, index) => (
                <div key={index} className="flex items-center justify-between bg-gray-50 p-2 rounded">
                  <div className="flex items-center">
                    <Clock className="w-4 h-4 text-blue-600 mr-2" />
                    <span className="font-mono text-sm">{time}</span>
                  </div>
                  <button
                    onClick={() => removeTime(time)}
                    className="text-red-600 hover:text-red-800 p-1"
                    title="Eliminar horario"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              ))}
              
              {config.scheduledExecution.times.length === 0 && (
                <p className="text-gray-500 text-sm italic">No hay horarios configurados</p>
              )}
            </div>

         {/* Agregar nuevo horario con selectores */}
            <div className="flex space-x-2 items-center">
              <select
                value={hour}
                onChange={(e) => {
                  const h = parseInt(e.target.value, 10);
                  setHour(h);
                  updatePreview(h, minute, period);
                }}
                className="px-2 py-2 border border-gray-300 rounded-md"
              >
                {Array.from({ length: 12 }, (_, i) => i + 1).map(h => (
                  <option key={h} value={h}>{h}</option>
                ))}
              </select>

              <select
                value={minute}
                onChange={(e) => {
                  const m = parseInt(e.target.value, 10);
                  setMinute(m);
                  updatePreview(hour, m, period);
                }}
                className="px-2 py-2 border border-gray-300 rounded-md"
              >
                {[0, 15, 30, 45].map(m => (
                  <option key={m} value={m}>{m.toString().padStart(2, '0')}</option>
                ))}
              </select>

              <select
                value={period}
                onChange={(e) => {
                  const p = e.target.value as 'AM' | 'PM';
                  setPeriod(p);
                  updatePreview(hour, minute, p);
                }}
                className="px-2 py-2 border border-gray-300 rounded-md"
              >
                <option value="AM">AM</option>
                <option value="PM">PM</option>
              </select>

              <button
                onClick={addTime}
                disabled={isRestarting}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors flex items-center disabled:opacity-50"
              >
                <Plus className="w-4 h-4 mr-1" />
                {isRestarting ? 'Reiniciando...' : 'Agregar'}
              </button>
            </div>

            {preview && (
              <p className="text-sm text-gray-500 mt-2">
                Vista previa: <span className="font-mono">{preview}</span>
              </p>
            )}
		  
		  {/* Palabras Clave */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Palabras Clave
            </label>
            <textarea
              value={config.scheduledExecution.keywords || ''}
              onChange={(e) => {
                const updatedConfig = {
                  ...config,
                  scheduledExecution: {
                    ...config.scheduledExecution,
                    keywords: e.target.value,
                  },
                };
                onConfigChange(updatedConfig);
              }}
              rows={3}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
              placeholder="Escriba palabras clave separadas por comas"
            />
          </div>
		  
		  {/* Switch SAE - Solo IDSAE Procesados */}
          <div className="flex items-center space-x-2">
            <input
              type="checkbox"
              id="switch-sae"
              checked={config.scheduledExecution.onlyIdSAEProcessed || false}
              onChange={(e) => {
                const updatedConfig = {
                  ...config,
                  scheduledExecution: {
                    ...config.scheduledExecution,
                    onlyIdSAEProcessed: e.target.checked,
                  },
                };
                onConfigChange(updatedConfig);
              }}
              className="h-4 w-4 text-blue-600 border-gray-300 rounded"
            />
            <label htmlFor="switch-sae" className="text-sm text-gray-700">
              Solo IDSAE Procesados
            </label>
          </div>

          {/* Informacion de ultima ejecucion */}
          {config.scheduledExecution.lastExecution && (
            <div className="bg-blue-50 p-3 rounded-lg">
              <p className="text-sm text-blue-800">
                <strong>Ultima ejecucion:</strong>{' '}
                {new Date(config.scheduledExecution.lastExecution).toLocaleString('es-MX', {
                  timeZone: 'America/Mexico_City'
                })}
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
};

export default ScheduleManager;