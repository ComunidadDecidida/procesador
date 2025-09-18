@echo off
echo Instalando controladores ODBC para Sistema de Gestion de Vigencias...
echo Version especifica - Firebird ODBC 2.0.5.156 x64 para Firebird 2.5

set DRIVERS_DIR=%~dp0drivers
if not exist "%DRIVERS_DIR%" mkdir "%DRIVERS_DIR%"

echo.
echo === VERIFICANDO DRIVERS EXISTENTES ===
echo Listando drivers ODBC actuales:
powershell -Command "Get-OdbcDriver | Where-Object {$_.Name -like '*Firebird*' -or $_.Name -like '*InterBase*'} | Select-Object Name, Platform"

echo.
echo === DESCARGANDO CONTROLADORES ODBC ===

echo Descargando Firebird ODBC Driver 2.0.5.156 x64 compatible con Firebird 2.5...
powershell -Command "try { Invoke-WebRequest -Uri 'https://github.com/FirebirdSQL/firebird-odbc-driver/releases/download/v2.0.5.156/Firebird_ODBC_2.0.5.156_x64.exe' -OutFile '%DRIVERS_DIR%\Firebird_ODBC_2.0.5.156_x64.exe' -ErrorAction Stop; Write-Host 'Descarga exitosa' } catch { Write-Host 'Error descargando Firebird ODBC: ' $_.Exception.Message; exit 1 }"

echo Descargando MySQL Connector/ODBC 9.4.0 x64...
powershell -Command "try { Invoke-WebRequest -Uri 'https://dev.mysql.com/get/Downloads/Connector-ODBC/mysql-connector-odbc-9.4.0-winx64.msi' -OutFile '%DRIVERS_DIR%\mysql-connector-odbc-9.4.0-winx64.msi' -ErrorAction Stop; Write-Host 'Descarga exitosa' } catch { Write-Host 'Error descargando MySQL ODBC: ' $_.Exception.Message; exit 1 }"

echo.
echo === INSTALANDO CONTROLADORES ===

echo Instalando Firebird ODBC Driver 2.0.5.156...
if exist "%DRIVERS_DIR%\Firebird_ODBC_2.0.5.156_x64.exe" (
    "%DRIVERS_DIR%\Firebird_ODBC_2.0.5.156_x64.exe" /SILENT
    timeout /t 10 /nobreak >nul
    echo Firebird ODBC 2.0.5.156 instalado
) else (
    echo ERROR: Archivo Firebird ODBC no encontrado
    exit 1
)

echo Instalando MySQL Connector/ODBC...
if exist "%DRIVERS_DIR%\mysql-connector-odbc-9.4.0-winx64.msi" (
    msiexec /i "%DRIVERS_DIR%\mysql-connector-odbc-9.4.0-winx64.msi" /quiet /norestart
    timeout /t 15 /nobreak >nul
    echo MySQL ODBC instalado
) else (
    echo ERROR: Archivo MySQL ODBC no encontrado
    exit 1
)

echo.
echo === VALIDANDO INSTALACION ===
echo Esperando que los drivers se registren en el sistema...
timeout /t 5 /nobreak >nul

echo Listando todos los drivers ODBC instalados:
powershell -Command "Get-OdbcDriver | Select-Object Name, Platform"

echo.
echo Drivers relacionados con Firebird y MySQL:
powershell -Command "Get-OdbcDriver | Where-Object {$_.Name -like '*Firebird*' -or $_.Name -like '*MySQL*' -or $_.Name -like '*InterBase*'} | Select-Object Name, Platform"

echo.
echo === PRUEBA BASICA DE CONECTIVIDAD ===
echo Probando creacion de objetos ODBC...
powershell -Command "try { $conn = New-Object System.Data.Odbc.OdbcConnection; Write-Host 'Objeto ODBC creado exitosamente' } catch { Write-Host 'Error creando objeto ODBC: ' $_.Exception.Message }"

echo.
echo === INSTALACION COMPLETADA ===
echo Los controladores ODBC han sido instalados exitosamente.
echo.
echo Controladores instalados:
echo - Firebird ODBC Driver 2.0.5.156 compatible con Firebird 2.5
echo - MySQL ODBC 9.4 Unicode Driver
echo.
echo IMPORTANTE: Reinicie la aplicacion para que los cambios surtan efecto.
echo.
pause