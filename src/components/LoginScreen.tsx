import React, { useState, useEffect } from 'react';
import { Eye, EyeOff, User, Lock, Shield, Database } from 'lucide-react';
import logoImage from '@assets/logo.png';

interface LoginScreenProps {
  onAuthenticated: () => void;
}

const LoginScreen: React.FC<LoginScreenProps> = ({ onAuthenticated }) => {
  const [isFirstSetup, setIsFirstSetup] = useState(false);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  useEffect(() => {
    checkUserExists();
  }, []);

  const checkUserExists = async () => {
    try {
      if (window.electronAPI?.checkUserExists) {
        const result = await window.electronAPI.checkUserExists();
        setIsFirstSetup(!result.exists);
      }
    } catch (error) {
      console.error('Error verificando usuario:', error);
      setIsFirstSetup(true);
    }
  };

  const handleLogin = async () => {
    if (!username || !password) {
      setError('Debe ingresar usuario y contraseña');
      return;
    }

    setLoading(true);
    setError('');

    try {
      if (window.electronAPI?.loginUser) {
        const result = await window.electronAPI.loginUser({ username, password });
        if (result.success) {
          onAuthenticated();
        } else {
          setError(result.error || 'Error de autenticación');
        }
      }
    } catch (error) {
      setError('Error de conexión');
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async () => {
    if (!username || !password) {
      setError('Debe ingresar usuario y contraseña');
      return;
    }

    if (password !== confirmPassword) {
      setError('Las contraseñas no coinciden');
      return;
    }

    if (password.length < 6) {
      setError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setLoading(true);
    setError('');

    try {
      if (window.electronAPI?.registerUser) {
        const result = await window.electronAPI.registerUser({ username, password });
        if (result.success) {
          onAuthenticated();
        } else {
          setError(result.error || 'Error al registrar usuario');
        }
      }
    } catch (error) {
      setError('Error de conexión');
    } finally {
      setLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      if (isFirstSetup) {
        handleRegister();
      } else {
        handleLogin();
      }
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-900 via-blue-800 to-indigo-900 flex items-center justify-center p-4 relative overflow-hidden">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute inset-0 bg-gradient-to-br from-blue-900/20 to-indigo-900/20"></div>
      </div>
      
      {/* Animated Background Elements */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute -top-40 -right-40 w-80 h-80 bg-blue-500 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-pulse"></div>
        <div className="absolute -bottom-40 -left-40 w-80 h-80 bg-indigo-500 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-pulse animation-delay-2000"></div>
        <div className="absolute top-40 left-40 w-60 h-60 bg-cyan-500 rounded-full mix-blend-multiply filter blur-xl opacity-20 animate-pulse animation-delay-4000"></div>
      </div>

      <div className="relative z-10 w-full max-w-md">
        {/* Logo Principal */}
        <div className="text-center mb-8">
          <div className="mx-auto w-32 h-32 mb-6 relative bg-white/10 rounded-full flex items-center justify-center backdrop-blur-sm border border-white/20">
            <img 
             src={logoImage} 
              alt="ETI Logo" 
              className="w-24 h-24 object-contain drop-shadow-2xl"
              onError={(e) => {
                e.currentTarget.style.display = 'none';
                (e.currentTarget.nextElementSibling as HTMLElement).style.display = 'flex';
              }}
            />
            <div className="hidden w-24 h-24 items-center justify-center text-white text-2xl font-bold">
              ETI
            </div>
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">
            Sistema de Gestion de Vigencias
          </h1>
          <p className="text-blue-200 text-sm">
            Enlaces en Telecomunicaciones Inalambricas
          </p>
        </div>

        {/* Login Card */}
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl shadow-2xl border border-white/20 p-8">
          <div className="text-center mb-6">
            <div className="mx-auto w-16 h-16 bg-blue-600 rounded-full flex items-center justify-center mb-4">
              {isFirstSetup ? <Shield className="w-8 h-8 text-white" /> : <Database className="w-8 h-8 text-white" />}
            </div>
            <h2 className="text-2xl font-bold text-white mb-2">
              {isFirstSetup ? 'Configuracion Inicial' : 'Iniciar Sesion'}
            </h2>
            <p className="text-blue-200 text-sm">
              {isFirstSetup 
                ? 'Configure su usuario administrador' 
                : 'Ingrese sus credenciales para continuar'
              }
            </p>
          </div>

          <div className="space-y-4">
            {/* Username Field */}
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <User className="h-5 w-5 text-blue-300" />
              </div>
              <input
                type="text"
                placeholder="Usuario"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                onKeyPress={handleKeyPress}
                className="w-full pl-10 pr-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent backdrop-blur-sm"
                disabled={loading}
              />
            </div>

            {/* Password Field */}
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Lock className="h-5 w-5 text-blue-300" />
              </div>
              <input
                type={showPassword ? "text" : "password"}
                placeholder="Contrasena"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                onKeyPress={handleKeyPress}
                className="w-full pl-10 pr-12 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent backdrop-blur-sm"
                disabled={loading}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute inset-y-0 right-0 pr-3 flex items-center text-blue-300 hover:text-white"
              >
                {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
              </button>
            </div>

            {/* Confirm Password Field (only for first setup) */}
            {isFirstSetup && (
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Lock className="h-5 w-5 text-blue-300" />
                </div>
                <input
                  type={showConfirmPassword ? "text" : "password"}
                  placeholder="Confirmar contrasena"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  onKeyPress={handleKeyPress}
                  className="w-full pl-10 pr-12 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent backdrop-blur-sm"
                  disabled={loading}
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center text-blue-300 hover:text-white"
                >
                  {showConfirmPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                </button>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="bg-red-500/20 border border-red-500/50 rounded-lg p-3">
                <p className="text-red-200 text-sm text-center">{error}</p>
              </div>
            )}

            {/* Submit Button */}
            <button
              onClick={isFirstSetup ? handleRegister : handleLogin}
              disabled={loading}
              className="w-full bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold py-3 px-4 rounded-lg transition-all duration-200 transform hover:scale-105 disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none shadow-lg"
            >
              {loading ? (
                <div className="flex items-center justify-center">
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                  Procesando...
                </div>
              ) : (
                isFirstSetup ? 'Crear Usuario Administrador' : 'Iniciar Sesion'
              )}
            </button>
          </div>

          {/* Additional Info */}
          <div className="mt-6 text-center">
            <p className="text-blue-200 text-xs">
              {isFirstSetup 
                ? 'Este usuario tendra acceso completo al sistema'
                : 'Contacte al administrador si olvido sus credenciales'
              }
            </p>
          </div>
        </div>

        {/* Footer */}
        <div className="text-center mt-8">
          <p className="text-blue-200 text-sm">
            (c) 2025 Enlaces en Telecomunicaciones Inalambricas
          </p>
          <p className="text-blue-300 text-xs mt-1">
            Sistema de Gestion de Vigencias v2.0.0
          </p>
        </div>
      </div>
    </div>
  );
};

export default LoginScreen;