import React, { useState, useEffect } from 'react';
import { Clock, MapPin, Wifi, WifiOff } from 'lucide-react';

interface ClockWidgetProps {
  className?: string;
}

const ClockWidget: React.FC<ClockWidgetProps> = ({ className = '' }) => {
  const [currentTime, setCurrentTime] = useState(new Date());
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [cdmxTime, setCdmxTime] = useState(new Date());

  useEffect(() => {
    // Verificar estado de conexion
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    // Funcion para actualizar tiempo CDMX con mayor precision
    const updateCdmxTime = () => {
      try {
        const now = new Date();
        // Usar Intl.DateTimeFormat para mayor precision
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
        
        const cdmxDateTime = new Date(year, month, day, hour, minute, second);
        setCdmxTime(cdmxDateTime);
        setCurrentTime(cdmxDateTime);
      } catch (error) {
        // Fallback: usar hora local
        const now = new Date();
        setCurrentTime(now);
        setCdmxTime(now);
      }
    };

    // Actualizar cada segundo
    const interval = setInterval(updateCdmxTime, 1000);
    
    // Actualizar inmediatamente
    updateCdmxTime();

    return () => {
      clearInterval(interval);
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('es-ES', {
      hour12: false,
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString('es-ES', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    });
  };

  return (
    <div className={`bg-white rounded-lg shadow-sm border p-3 min-w-[200px] ${className}`}>
      <div className="flex items-center justify-between mb-2">
        <div className="flex items-center">
          <Clock className="w-5 h-5 text-blue-600 mr-2" />
          <span className="text-xs font-medium text-gray-700">CDMX Mexico</span>
        </div>
        <div className="flex items-center text-xs text-gray-500">
          {isOnline ? <Wifi className="w-3 h-3 mr-1" /> : <WifiOff className="w-3 h-3 mr-1" />}
          <span className={isOnline ? 'text-green-600' : 'text-red-600'}>
            {isOnline ? 'Online' : 'Offline'}
          </span>
        </div>
      </div>
      
      <div className="text-center">
        <div className="text-xl font-bold text-gray-800 font-mono tracking-wider">
          {formatTime(currentTime)}
        </div>
        <div className="text-xs text-gray-600 mt-1 capitalize">
          {formatDate(currentTime)}
        </div>
        <div className="text-xs text-blue-600 mt-1">
          UTC-6 (Zona Centro)
        </div>
      </div>
    </div>
  );
};

export default ClockWidget;