# VigenciasProcessor.ps1
# Sistema de Gestion de Vigencias - Procesador Principal ODBC
# PowerShell 5.1 + System.Data.Odbc (sin DLLs externas)
# Compatible con SAE 9 Firebird 2.5 x64

param(
    [Parameter(Mandatory=$true)]
    [string]$Operation,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigJson = "{}",
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "",
    
    [Parameter(Mandatory=$false)]
    [int]$DiasFacturas = 5,
    
    [Parameter(Mandatory=$false)]
    [int]$VigenciaDia = 9,
    
    [Parameter(Mandatory=$false)]
    [int]$VigenciaConvenio = 35,
    
    [Parameter(Mandatory=$false)]
    [int]$VigenciaCicloEscolar = 365
)

# Configurar encoding para caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Variables globales
$scriptRoot = Split-Path -Parent $PSCommandPath
$configPath = Join-Path $scriptRoot "config.json"
# Configuracion adicional para MySQL
$MySQLCharsets = @(
    "NONE",
    "utf8",
    "utf8mb4", 
    "latin1",
    "ascii",
    "cp1252",
    "cp850",
    "cp866",
    "koi8r",
    "koi8u",
    "big5",
    "gb2312",
    "gbk",
    "sjis",
    "ujis",
    "euckr",
    "tis620",
    "cp932",
    "eucjpms",
    "cp1250",
    "cp1251",
    "cp1256",
    "cp1257",
    "hebrew",
    "greek",
    "dec8",
    "hp8",
    "swe7",
    "armscii8",
    "geostd8",
    "keybcs2",
    "macce",
    "macroman",
    "cp852",
    "latin2",
    "latin5",
    "latin7",
    "cp1254",
    "ucs2",
    "utf16",
    "utf16le",
    "utf32",
    "binary"
)

$logsPath = Join-Path $scriptRoot "logs"

# Crear directorio de logs si no existe
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}

# Funcion para escribir logs (solo a stderr para no interferir con JSON)
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Host.UI.WriteErrorLine("[$timestamp] [$Level] $Message")
}

# Funcion para validar drivers ODBC instalados
function Assert-OdbcDrivers {
    try {
        $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
        
        # Verificar Firebird ODBC 2.0.5.156 especificamente para Firebird 2.5
        $firebirdDriverFound = $false
        $firebirdDriverPatterns = @("Firebird/InterBase(r) driver")
        foreach ($pattern in $firebirdDriverPatterns) {
            if ($drivers -contains $pattern) {
                $firebirdDriverFound = $true
                Write-Log "Driver Firebird encontrado: $pattern" "SUCCESS"
                break
            }
        }
        
        if (-not $firebirdDriverFound) {
            $availableDrivers = $drivers -join ", "
            Write-Log "Drivers disponibles: $availableDrivers" "INFO"
            throw "Driver ODBC Firebird/InterBase(r) driver no esta instalado. Se requiere Firebird ODBC 2.0.5.156 para Firebird 2.5"
        }
        
        # Verificar MySQL ODBC (permitir versiones 8.0, 9.0 y 9.4)
        $mysqlDriverFound = $false
        $mysqlDriverPatterns = @("MySQL ODBC 8.0 Unicode Driver", "MySQL ODBC 9.0 Unicode Driver", "MySQL ODBC 9.4 Unicode Driver")
        foreach ($pattern in $mysqlDriverPatterns) {
            if ($drivers -contains $pattern) {
                $mysqlDriverFound = $true
                break
            }
        }
        
        if (-not $mysqlDriverFound) {
            $availableDrivers = $drivers -join ", "
            throw "Driver ODBC de MySQL no esta instalado. Drivers disponibles: $availableDrivers"
        }
        
        Write-Log "Drivers ODBC validados correctamente" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error validando drivers ODBC: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Funcion para cargar configuracion
function Load-Config {
    try {
        if (Test-Path $configPath) {
            $configContent = Get-Content $configPath -Raw -Encoding UTF8
            $config = $configContent | ConvertFrom-Json
            Write-Log "Configuracion cargada desde: $configPath" "INFO"
            return $config
        } else {
            throw "Archivo de configuracion no encontrado: $configPath"
        }
    }
    catch {
        Write-Log "Error cargando configuracion: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# Funcion para construir cadena de conexion Firebird ODBC compatible con SAE 9
function Build-FirebirdConnectionString {
    param([PSCustomObject]$Config)
    
    try {
        $firebirdDriver = "Firebird/InterBase(r) driver"
        
        if ($Config.PSObject.Properties.Name -contains "odbcDriverName" -and $Config.odbcDriverName) {
            $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
            if ($drivers -contains $Config.odbcDriverName) {
                $firebirdDriver = $Config.odbcDriverName
                Write-Log "Usando driver configurado: $firebirdDriver" "INFO"
            } else {
                Write-Log "Driver configurado no encontrado, usando default: $firebirdDriver" "WARN"
            }
        }
        
        $dbPath = ""
        if ($Config.PSObject.Properties.Name -contains "databasePath" -and $Config.databasePath) {
            $dbPath = $Config.databasePath
        } elseif ($Config.PSObject.Properties.Name -contains "database" -and $Config.database) {
            $dbPath = $Config.database
        } else {
            throw "No se especifico la ruta de la base de datos"
        }
        
        if (-not (Test-Path $dbPath)) {
            Write-Log "Advertencia: Archivo de base de datos no encontrado: $dbPath" "WARN"
        }
        
        $parts = @()
        $parts += "Driver={$firebirdDriver}"
        $parts += "Dbname=$dbPath"
        $parts += "Uid=$($Config.user)"
        $parts += "Pwd=$($Config.password)"
        $parts += "CharSet=WIN1252"
        $parts += "Dialect=3"
        $parts += "ReadOnly=0"
        $parts += "NoWait=0"
        
        $connectionString = ($parts -join ";")
        
        Write-Log "Cadena de conexion Firebird SAE 9 construida para driver: $firebirdDriver" "INFO"
        Write-Log "Base de datos: $dbPath" "INFO"
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion Firebird: $($_.Exception.Message)"
    }
}

# Funcion mejorada para construir cadena de conexion MySQL ODBC con charset y SSL
function Build-MySQLConnectionStringAdvanced {
    param([PSCustomObject]$Config)
    
    try {
        # Detectar version del driver MySQL ODBC instalado
        $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
        $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"  # Default fallback
        
        if ($drivers -contains "MySQL ODBC 9.4 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.4 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 9.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.0 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 8.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"
        }
        
        $parts = @()
        $parts += "Driver={$mysqlDriver}"
        $parts += "Server=$($Config.host)"
        $parts += "Port=$($Config.port)"
        $parts += "Database=$($Config.database)"
        $parts += "User=$($Config.user)"
        $parts += "Password=$($Config.password)"
        
        # Configuracion de charset
        if ($Config.PSObject.Properties.Name -contains "charset" -and $Config.charset -and $Config.charset -ne "NONE") {
            $parts += "CharSet=$($Config.charset)"
            Write-Log "Usando charset MySQL: $($Config.charset)" "INFO"
        }
        
        # Configuracion SSL
        if ($Config.PSObject.Properties.Name -contains "sslEnabled" -and $Config.sslEnabled -eq $true) {
            $parts += "SSLMode=Required"
            Write-Log "SSL habilitado para MySQL" "INFO"
        } else {
            $parts += "SSLMode=Disabled"
            Write-Log "SSL deshabilitado para MySQL" "INFO"
        }
        
        $parts += "Option=3"
        
        $connectionString = ($parts -join ";")
        Write-Log "Usando driver MySQL: $mysqlDriver" "INFO"
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion MySQL avanzada: $($_.Exception.Message)"
    }
}

# Funcion para obtener charsets MySQL disponibles
function Get-MySQLCharsets {
    return @{
        success = $true
        charsets = $MySQLCharsets
    }
}

# Funcion para construir cadena de conexion MySQL ODBC
function Build-MySQLConnectionString {
    param([PSCustomObject]$Config)
    
    try {
        $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
        $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"
        
        if ($drivers -contains "MySQL ODBC 9.4 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.4 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 9.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.0 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 8.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"
        }
        
        $connectionString = @(
            "Driver={$mysqlDriver}",
            "Server=$($Config.host)",
            "Port=$($Config.port)",
            "Database=$($Config.database)",
            "User=$($Config.user)",
            "Password=$($Config.password)",
            "SSLMode=Preferred",
            "Option=3"
        ) -join ";"
        
        Write-Log "Usando driver MySQL: $mysqlDriver" "INFO"
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion MySQL: $($_.Exception.Message)"
    }
}

# Funcion para formatear fecha para MySQL (dd/MM/yyyy)
function Format-DateForMySQL {
    param([DateTime]$Date)
    return $Date.ToString("dd/MM/yyyy")
}

# Funcion para parsear fecha desde MySQL
function Parse-DateFromMySQL {
    param([string]$DateString)
    
    if ([string]::IsNullOrWhiteSpace($DateString)) {
        return $null
    }
    
    try {
        if ($DateString -match '^\d{1,2}/\d{1,2}/\d{4}$') {
            return [DateTime]::ParseExact($DateString, "dd/MM/yyyy", $null)
        }
        
        if ($DateString -match '^\d{4}-\d{1,2}-\d{1,2}$') {
            return [DateTime]::ParseExact($DateString, "yyyy-MM-dd", $null)
        }
        
        return [DateTime]::Parse($DateString)
    }
    catch {
        Write-Log "Error parseando fecha '$DateString': $($_.Exception.Message)" "WARN"
        return $null
    }
}

# Funcion para probar conexion Firebird ODBC
function Test-FirebirdConnection {
    param([PSCustomObject]$Config)
    
    $startTime = Get-Date
    $conn = $null
    
    try {
        Write-Log "Probando conexion Firebird ODBC 2.0.5.156 SAE 9" "INFO"
        
        $connectionString = Build-FirebirdConnectionString -Config $Config
        Write-Log "Cadena de conexion: $($connectionString -replace 'Pwd=[^;]*', 'Pwd=***')" "INFO"
        
        $conn = New-Object System.Data.Odbc.OdbcConnection
        $conn.ConnectionString = $connectionString
        $conn.ConnectionTimeout = if ($Config.PSObject.Properties.Name -contains "connectionTimeout" -and $Config.connectionTimeout) { $Config.connectionTimeout } else { 30 }
        
        Write-Log "Intentando abrir conexion..." "INFO"
        $conn.Open()
        
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            Write-Log "Conexion abierta exitosamente, probando consulta..." "INFO"
            
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT CURRENT_TIMESTAMP FROM RDB`$DATABASE"
            $cmd.CommandTimeout = 10
            $result = $cmd.ExecuteScalar()
            
            $elapsed = (Get-Date) - $startTime
            Write-Log "Conexion Firebird SAE 9 exitosa en $($elapsed.TotalMilliseconds)ms - Tiempo servidor: $result" "SUCCESS"
            
            return @{
                success = $true
                message = "Conexion exitosa en $($elapsed.TotalMilliseconds.ToString('F2'))ms"
            }
        }
        else {
            throw "Conexion fallo - Estado: $($conn.State)"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Conexion Firebird fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
        }
    }
    finally {
        if ($conn -and $conn.State -eq [System.Data.ConnectionState]::Open) {
            try {
                $conn.Close()
                Write-Log "Conexion cerrada correctamente" "INFO"
            }
            catch {
                Write-Log "Error cerrando conexion: $($_.Exception.Message)" "WARN"
            }
        }
    }
}

# Funcion para probar conexion MySQL ODBC
function Test-MySQLConnection {
    param([PSCustomObject]$Config)
    
    $startTime = Get-Date
    $conn = $null
    
    try {
        Write-Log "Probando conexion MySQL ODBC" "INFO"
        
        $connectionString = Build-MySQLConnectionStringAdvanced -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT NOW() as server_time"
            $result = $cmd.ExecuteScalar()
            
            $elapsed = (Get-Date) - $startTime
            Write-Log "Conexion MySQL ODBC exitosa en $($elapsed.TotalMilliseconds)ms - Tiempo servidor: $result" "SUCCESS"
            
            return @{
                success = $true
                message = "Conexion exitosa en $($elapsed.TotalMilliseconds.ToString('F2'))ms"
            }
        }
        else {
            throw "Conexion fallo - Estado: $($conn.State)"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Conexion MySQL ODBC fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
        }
    }
    finally {
        if ($conn -and $conn.State -eq [System.Data.ConnectionState]::Open) {
            try {
                $conn.Close()
                Write-Log "Conexion cerrada correctamente" "INFO"
            }
            catch {
                Write-Log "Error cerrando conexion: $($_.Exception.Message)" "WARN"
            }
        }
    }
}

# Funcion para copiar base de datos
function Copy-Database {
    param([string]$SourcePath, [string]$DestinationPath)
    
    try {
        Write-Log "Iniciando copia de base de datos" "INFO"
        Write-Log "Origen: $SourcePath" "INFO"
        Write-Log "Destino: $DestinationPath" "INFO"
        
        if (-not (Test-Path $SourcePath)) {
            throw "Archivo origen no encontrado: $SourcePath"
        }
        
        $sourceSize = (Get-Item $SourcePath).Length
        Write-Log "Tamano archivo origen: $([math]::Round($sourceSize / 1MB, 2)) MB" "INFO"
        
        $destinationDir = Split-Path $DestinationPath -Parent
        if (-not (Test-Path $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            Write-Log "Directorio destino creado: $destinationDir" "INFO"
        }
        
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        
        if (Test-Path $DestinationPath) {
            $destSize = (Get-Item $DestinationPath).Length
            Write-Log "Tamano archivo destino: $([math]::Round($destSize / 1MB, 2)) MB" "INFO"
            
            if ($sourceSize -eq $destSize) {
                Write-Log "Copia de base de datos completada exitosamente" "SUCCESS"
                
                # Estabilizacion post-copia
                Write-Log "Estabilizando sistema post-copia (10 segundos)..." "INFO"
                Start-Sleep -Seconds 10
                
                return @{
                    success = $true
                    message = "Base de datos copiada exitosamente"
                    source_size = $sourceSize
                    destination_size = $destSize
                }
            } else {
                throw "Error en integridad: tamanos diferentes (origen: $sourceSize, destino: $destSize)"
            }
        } else {
            throw "Archivo destino no fue creado"
        }
    }
    catch {
        Write-Log "Error copiando base de datos: $($_.Exception.Message)" "ERROR"
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# Funcion para sincronizar clientes (OPTIMIZADA - Solo insercion de nuevos)
function Sync-Clientes {
    $startTime = Get-Date
    $config = Load-Config
    
    try {
        Write-Log "Iniciando sincronizacion masiva de clientes Firebird SAE 9 -> MySQL" "INFO"
        Write-Log "MODO: Solo insercion de clientes nuevos (sin actualizaciones)" "INFO"
        
        # Paso 1: Extraer todos los clientes de Firebird SAE 9
        Write-Log "Extrayendo clientes de Firebird SAE 9..." "INFO"
        $firebirdConnectionString = Build-FirebirdConnectionString -Config $config.firebird
        $firebirdConn = New-Object System.Data.Odbc.OdbcConnection($firebirdConnectionString)
        $firebirdConn.Open()
        
        $firebirdCmd = $firebirdConn.CreateCommand()
        $firebirdCmd.CommandText = @"
SELECT c.CLAVE AS IDSAE,
TRIM(REPLACE(REPLACE(REPLACE(COALESCE(c.NOMBRECOMERCIAL, ''), '/', ''), '  ', ' '), '   ', ' ')) AS Nombre,
COALESCE(c.CALLE, '') AS CALLE,
COALESCE(c.NUMINT, '') AS NUMINT,
COALESCE(c.NUMEXT, '') AS NUMEXT,
COALESCE(c.TELEFONO, '') AS TELEFONO,
COALESCE(c.EMAILPRED, '') AS CorreoElectronico
FROM CLIE01 c
WHERE c.CLAVE <> 'MOSTR' AND c.STATUS = 'A'
ORDER BY c.CLAVE ASC
"@
        
        $firebirdReader = $firebirdCmd.ExecuteReader()
        $clientes = @()
        
        while ($firebirdReader.Read()) {
            $idsae = $firebirdReader["IDSAE"].ToString().Trim()
            $nombre = $firebirdReader["Nombre"].ToString().Trim()
            $calle = $firebirdReader["CALLE"].ToString().Trim()
            $numInt = $firebirdReader["NUMINT"].ToString().Trim()
            $numExt = $firebirdReader["NUMEXT"].ToString().Trim()
            
            # Procesar telefono - separar multiples valores con ";" sin espacios
            $telefonoRaw = $firebirdReader["TELEFONO"].ToString().Trim()
            $telefono = if ($telefonoRaw -match '[,\s]+') {
                ($telefonoRaw -split '[,\s]+' | Where-Object { $_.Trim() -ne '' }) -join ';'
            } else {
                $telefonoRaw
            }
            
            # Procesar correo electronico - separar multiples valores con ";" sin espacios
            $correoRaw = $firebirdReader["CorreoElectronico"].ToString().Trim()
            $correoElectronico = if ($correoRaw -match '[,\s]+') {
                ($correoRaw -split '[,\s]+' | Where-Object { $_.Trim() -ne '' }) -join ';'
            } else {
                $correoRaw
            }
            
            $clientes += @{
                IDSAE = $idsae
                Nombre = $nombre
                Calle = $calle
                NumInt = $numInt
                NumExt = $numExt
                Telefono = $telefono
                CorreoElectronico = $correoElectronico
            }
        }
        
        $firebirdReader.Close()
        $firebirdConn.Close()
        
        Write-Log "Extraidos $($clientes.Count) clientes de Firebird SAE 9" "SUCCESS"
        
        # Paso 2: Conectar a MySQL y crear tabla temporal
        Write-Log "Conectando a MySQL y creando tabla temporal..." "INFO"
        $mysqlConnectionString = Build-MySQLConnectionString -Config $config.mysql
        $mysqlConn = New-Object System.Data.Odbc.OdbcConnection($mysqlConnectionString)
        $mysqlConn.Open()
        
        # Crear tabla temporal en memoria
        $createTempTableSQL = @"
CREATE TEMPORARY TABLE temp_clientes_sync (
    IDSAE VARCHAR(50) PRIMARY KEY,
    Nombre VARCHAR(255),
    Calle VARCHAR(255),
    NumInt VARCHAR(50),
    NumExt VARCHAR(50),
    Telefono VARCHAR(50),
    CorreoElectronico VARCHAR(255)
) ENGINE=MEMORY
"@
        
        $mysqlCmd = $mysqlConn.CreateCommand()
        $mysqlCmd.CommandText = $createTempTableSQL
        $mysqlCmd.ExecuteNonQuery()
        
        Write-Log "Tabla temporal creada exitosamente" "SUCCESS"
        
        # Paso 3: Cargar datos en lotes a tabla temporal
        Write-Log "Cargando datos en lotes a tabla temporal..." "INFO"
        $batchSize = 500
        $totalBatches = [math]::Ceiling($clientes.Count / $batchSize)
        
        for ($i = 0; $i -lt $clientes.Count; $i += $batchSize) {
            $batch = $clientes[$i..([math]::Min($i + $batchSize - 1, $clientes.Count - 1))]
            $batchNumber = [math]::Floor($i / $batchSize) + 1
            
            $values = @()
            foreach ($cliente in $batch) {
                $idsae = $cliente.IDSAE -replace "'", "''"
                $nombre = $cliente.Nombre -replace "'", "''"
                $calle = $cliente.Calle -replace "'", "''"
                $numInt = $cliente.NumInt -replace "'", "''"
                $numExt = $cliente.NumExt -replace "'", "''"
                $telefono = $cliente.Telefono -replace "'", "''"
                $correoElectronico = $cliente.CorreoElectronico -replace "'", "''"
                
                $values += "('$idsae', '$nombre', '$calle', '$numInt', '$numExt', '$telefono', '$correoElectronico')"
            }
            
            $insertSQL = "INSERT INTO temp_clientes_sync (IDSAE, Nombre, Calle, NumInt, NumExt, Telefono, CorreoElectronico) VALUES " + ($values -join ", ")
            
            $mysqlCmd.CommandText = $insertSQL
            $mysqlCmd.ExecuteNonQuery()
            
            Write-Log "Lote $batchNumber/$totalBatches cargado: $($batch.Count) registros" "INFO"
        }
        
        Write-Log "Carga masiva completada: $($clientes.Count) registros en tabla temporal" "SUCCESS"
        
        # Paso 4: Sincronizacion masiva - SOLO INSERCION DE NUEVOS
        Write-Log "Sincronizando datos masivamente (solo nuevos registros)..." "INFO"
        
        # 4A: Insertar solo nuevos en Asociado
        $insertAsociadoSQL = @"
INSERT INTO Asociado (IDSAE, Nombre)
SELECT t.IDSAE, t.Nombre
FROM temp_clientes_sync t
LEFT JOIN Asociado a ON t.IDSAE = a.IDSAE
WHERE a.IDSAE IS NULL
"@
        
        $mysqlCmd.CommandText = $insertAsociadoSQL
        $clientesInserted = $mysqlCmd.ExecuteNonQuery()
        Write-Log "Insertados $clientesInserted nuevos registros en tabla Asociado" "SUCCESS"
        
        # 4B: Insertar solo nuevos en Direccion
        $insertDireccionSQL = @"
INSERT INTO Direccion (IDSAE, Calle, NumInt, NumExt)
SELECT t.IDSAE, t.Calle, t.NumInt, t.NumExt
FROM temp_clientes_sync t
LEFT JOIN Direccion d ON t.IDSAE = d.IDSAE
WHERE d.IDSAE IS NULL
"@
        
        $mysqlCmd.CommandText = $insertDireccionSQL
        $direccionesInserted = $mysqlCmd.ExecuteNonQuery()
        Write-Log "Insertadas $direccionesInserted nuevas direcciones" "SUCCESS"
        
        # 4C: Insertar solo nuevos en DatosAdicionales
        $insertDatosSQL = @"
INSERT INTO DatosAdicionales (IDSAE, CorreoElectronico, Telefono)
SELECT t.IDSAE, t.CorreoElectronico, t.Telefono
FROM temp_clientes_sync t
LEFT JOIN DatosAdicionales da ON t.IDSAE = da.IDSAE
WHERE da.IDSAE IS NULL
"@
        
        $mysqlCmd.CommandText = $insertDatosSQL
        $datosInserted = $mysqlCmd.ExecuteNonQuery()
        Write-Log "Insertados $datosInserted nuevos registros de datos adicionales" "SUCCESS"
        
        # Paso 5: Limpiar tabla temporal
        $mysqlCmd.CommandText = "DROP TEMPORARY TABLE temp_clientes_sync"
        $mysqlCmd.ExecuteNonQuery()
        Write-Log "Tabla temporal eliminada" "SUCCESS"
        
        $mysqlConn.Close()
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Sincronizacion masiva completada en $($elapsed.TotalMinutes.ToString('F2')) minutos" "SUCCESS"
        Write-Log "Resumen: $clientesInserted nuevos asociados, $direccionesInserted nuevas direcciones, $datosInserted nuevos datos adicionales" "SUCCESS"
        
        # Estabilizacion post-sincronizacion
        Write-Log "Estabilizando conexiones post-sincronizacion (15 segundos)..." "INFO"
        Start-Sleep -Seconds 15
        
        return @{
            success = $true
            message = "Sincronizacion completada exitosamente"
            clientes_insertados = $clientesInserted
            direcciones_insertadas = $direccionesInserted
            datos_insertados = $datosInserted
            tiempo_total = $elapsed.TotalMinutes.ToString('F2')
        }
    }
    catch {
        Write-Log "Error en sincronizacion masiva: $($_.Exception.Message)" "ERROR"
        
        if ($mysqlConn -and $mysqlConn.State -eq [System.Data.ConnectionState]::Open) {
            try {
                $mysqlConn.Close()
            }
            catch {
                Write-Log "Error cerrando conexion MySQL: $($_.Exception.Message)" "WARN"
            }
        }
        
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# Funcion para exportar registros
function Export-Registros {
    param([string]$OutputPath, [int]$DiasFacturas)
    
    $startTime = Get-Date
    $config = Load-Config
    
    try {
        Write-Log "Iniciando exportacion de registros desde Firebird SAE 9" "INFO"
        Write-Log "Periodo: ultimos $DiasFacturas dias" "INFO"
        Write-Log "Ruta de salida: $OutputPath" "INFO"
        
        $connectionString = Build-FirebirdConnectionString -Config $config.firebird
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        # Construir filtros dinamicos de palabras prohibidas
        $palabrasProhibidas = $config.rules.palabrasProhibidas
        $filtrosSQL = @()
        foreach ($palabra in $palabrasProhibidas) {
            $filtrosSQL += "UPPER(od.STR_OBS) NOT LIKE '%$($palabra.ToUpper())%'"
        }
        $filtrosWhere = $filtrosSQL -join " AND "
        
        $query = @"
SELECT c.CLAVE, c.CALLE, c.NUMINT, c.NUMEXT, c.TELEFONO, c.EMAILPRED, c.NOMBRECOMERCIAL, c.RFC,
f.CVE_DOC, f.FOLIO, f.IMPORTE, od.STR_OBS,
EXTRACT(DAY FROM f.FECHAELAB) AS DIA,
EXTRACT(MONTH FROM f.FECHAELAB) AS MES,
EXTRACT(YEAR FROM f.FECHAELAB) AS ANO
FROM CLIE01 c
INNER JOIN FACTF01 f ON f.CVE_CLPV = c.CLAVE
INNER JOIN PAR_FACTF01 pf ON pf.CVE_DOC = f.CVE_DOC
INNER JOIN OBS_DOCF01 od ON od.CVE_OBS = pf.CVE_OBS
WHERE f.FECHA_DOC >= CURRENT_DATE - $DiasFacturas
AND $filtrosWhere
AND f.FECHA_CANCELA IS NULL
ORDER BY f.FECHAELAB DESC
"@
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        
        $reader = $cmd.ExecuteReader()
        
        $registrosFile = Join-Path $OutputPath "Registros.txt"
        $csvContent = @()
        $csvContent += "IDSAE,FACTURA,FECHA,OBSERVACIONES,IMPORTE,CALLE,NUMINT,NUMEXT,TELEFONO,EMAIL,NOMBRECOMERCIAL,RFC,FOLIO"
        
        $recordCount = 0
        while ($reader.Read()) {
            $dia = $reader["DIA"].ToString().PadLeft(2, '0')
            $mes = $reader["MES"].ToString().PadLeft(2, '0')
            $ano = $reader["ANO"].ToString()
            $fechaFormateada = "$dia/$mes/$ano"
            
            $idsae = $reader["CLAVE"].ToString().Trim()
            $factura = $reader["CVE_DOC"].ToString().Trim()
            $observaciones = $reader["STR_OBS"].ToString().Trim() -replace '"', '""'
            $importe = $reader["IMPORTE"].ToString().Trim()
            $calle = $reader["CALLE"].ToString().Trim() -replace '"', '""'
            $numint = $reader["NUMINT"].ToString().Trim()
            $numext = $reader["NUMEXT"].ToString().Trim()
            $telefono = $reader["TELEFONO"].ToString().Trim()
            $email = $reader["EMAILPRED"].ToString().Trim()
            $nombreComercial = $reader["NOMBRECOMERCIAL"].ToString().Trim() -replace '"', '""'
            $rfc = $reader["RFC"].ToString().Trim()
            $folio = $reader["FOLIO"].ToString().Trim()
            
            $csvLine = "`"$idsae`",`"$factura`",`"$fechaFormateada`",`"$observaciones`",`"$importe`",`"$calle`",`"$numint`",`"$numext`",`"$telefono`",`"$email`",`"$nombreComercial`",`"$rfc`",`"$folio`""
            $csvContent += $csvLine
            $recordCount++
        }
        
        $reader.Close()
        $conn.Close()
        
        # Escribir archivo
        $csvContent | Out-File -FilePath $registrosFile -Encoding UTF8
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Exportacion completada: $recordCount registros en $($elapsed.TotalMinutes.ToString('F2')) minutos" "SUCCESS"
        Write-Log "Archivo generado: $registrosFile" "SUCCESS"
        
        # Estabilizacion post-exportacion
        Write-Log "Estabilizando archivos post-exportacion (5 segundos)..." "INFO"
        Start-Sleep -Seconds 5
        
        return @{
            success = $true
            message = "Registros exportados exitosamente"
            records_count = $recordCount
            output_file = $registrosFile
            tiempo_total = $elapsed.TotalMinutes.ToString('F2')
        }
    }
    catch {
        Write-Log "Error exportando registros: $($_.Exception.Message)" "ERROR"
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# Funcion para calcular vigencia de CUOTA DE MANTENIMIENTO con logica estricta
function Calculate-VigenciaCuotaMantenimiento {
    param(
        [string]$Observaciones,
        [DateTime]$FechaFactura,
        [int]$VigenciaDia
    )
    
    try {
        Write-Log "Calculando vigencia CUOTA MANTENIMIENTO (logica simplificada) para: $Observaciones" "INFO"
        
        # 1. Buscar el ultimo ano valido (>= ano de factura) en las observaciones
        $anosEncontrados = [regex]::Matches($Observaciones, '\b(20\d{2})\b')
        $anoValido = $null
        
        foreach ($match in $anosEncontrados) {
            $ano = [int]$match.Groups[1].Value
            if ($ano -ge $FechaFactura.Year) {
                $anoValido = $ano  # Tomar el ultimo encontrado
                Write-Log "Ano valido encontrado: $ano" "INFO"
            }
        }
        
        # CONDICION ESTRICTA: Si no hay ano valido, NO PROCESAR
        if ($anoValido -eq $null) {
            Write-Log "No se encontro ano valido en observaciones (>= $($FechaFactura.Year))" "WARN"
            return $null
        }
        
        # 2. Buscar el ultimo mes mencionado (lado derecho)
        $mesesMap = @{
            "ENERO" = 1; "FEBRERO" = 2; "FEBERO" = 2; "MARZO" = 3; "ABRIL" = 4;
            "MAYO" = 5; "JUNIO" = 6; "JUNO" = 6; "JUNI" = 6; "JULIO" = 7; "JULO" = 7; "JULI" = 7; "AGOSTO" = 8;
            "SEPTIEMBRE" = 9; "SEPTEMBRE" = 9; "OCTUBRE" = 10; "OCTOBRE" = 10; "NOVIEMBRE" = 11; "NOVEMBRE" = 11; "DICIEMBRE" = 12; "DICEMBRE" = 12
        }
        
        $ultimoMes = $null
        $ultimaPosicion = -1
        
        foreach ($mesNombre in $mesesMap.Keys) {
            $posicion = $Observaciones.ToUpper().LastIndexOf($mesNombre)
            if ($posicion -gt $ultimaPosicion) {
                $ultimaPosicion = $posicion
                $ultimoMes = @{
                    Nombre = $mesNombre
                    Numero = $mesesMap[$mesNombre]
                    Posicion = $posicion
                }
                Write-Log "Ultimo mes encontrado: $mesNombre (posicion $posicion)" "INFO"
            }
        }
        
        # Verificar que se encontro un mes
        if ($ultimoMes -eq $null) {
            Write-Log "No se encontro ningun mes valido en observaciones" "WARN"
            return $null
        }
        
        # 3. Crear fecha base con el ultimo mes y ano valido
        $mesNumero = [int]$ultimoMes.Numero
        $anoFinal = [int]$anoValido
        
        try {
            $fechaBase = New-Object DateTime($anoFinal, $mesNumero, 1)
            Write-Log "Fecha base creada: $($fechaBase.ToString('MM/yyyy'))" "INFO"
        }
        catch {
            Write-Log "Error creando fecha base con ano=$anoFinal, mes=$mesNumero`: $($_.Exception.Message)" "ERROR"
            return $null
        }
        
        # 4. Calcular vigencia: dia configurado del mes siguiente
        $mesVigencia = $fechaBase.Month + 1
        $anoVigencia = $fechaBase.Year
        
        if ($mesVigencia -gt 12) {
            $mesVigencia = 1
            $anoVigencia++
        }
        
        # 5. Ajustar dia para evitar fechas invalidas (ej: 31 de febrero)
        $maxDayInMonth = [System.DateTime]::DaysInMonth($anoVigencia, $mesVigencia)
        $diaAjustado = [System.Math]::Min($VigenciaDia, $maxDayInMonth)
        
        try {
            $vigenciaFinal = New-Object DateTime($anoVigencia, $mesVigencia, $diaAjustado)
            
            # 6. Validacion final: vigencia debe ser >= fecha factura
            if ($vigenciaFinal.Date -ge $FechaFactura.Date) {
                Write-Log "Vigencia CUOTA MANTENIMIENTO calculada: $($vigenciaFinal.ToString('dd/MM/yyyy'))" "SUCCESS"
                return $vigenciaFinal
            }
            else {
                Write-Log "Vigencia calculada $($vigenciaFinal.ToString('dd/MM/yyyy')) es anterior a fecha factura $($FechaFactura.ToString('dd/MM/yyyy'))" "WARN"
                return $null
            }
        }
        catch {
            Write-Log "Error creando vigencia final con ano=$anoVigencia, mes=$mesVigencia, dia=$diaAjustado`: $($_.Exception.Message)" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error general calculando vigencia CUOTA MANTENIMIENTO: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Funcion para procesar vigencias desde archivo con jerarquia estricta
function Process-VigenciasFromTxt {
    param([string]$OutputPath, [int]$VigenciaDia, [int]$VigenciaConvenio, [int]$VigenciaCicloEscolar)
    
    $startTime = Get-Date
    $config = Load-Config
    
    try {
        Write-Log "Iniciando procesamiento de vigencias con jerarquia A->B->C->D" "INFO"
        
        $registrosFile = Join-Path $OutputPath "Registros.txt"
        if (-not (Test-Path $registrosFile)) {
            throw "Archivo Registros.txt no encontrado: $registrosFile"
        }
        
        $lines = Get-Content $registrosFile -Encoding UTF8
        if ($lines.Count -le 1) {
            throw "Archivo Registros.txt vacio o solo contiene encabezado"
        }
        
        Write-Log "Procesando $($lines.Count - 1) registros con jerarquia estricta" "INFO"
        
        # Hashtable para mantener solo vigencia mayor por IDSAE
        $vigenciasPorIDSAE = @{}
        $registrosProcesados = @()
        $registrosProcesados += "IDSAE,FACTURA,FECHA_FACTURA,OBSERVACIONES,VIGENCIA,TIPO"
        
		# Lista para registros no procesados
        $registrosNoProcesados = @()
        $registrosNoProcesados += "IDSAE,FACTURA,FECHA_FACTURA,OBSERVACIONES,RAZON"
		
        $procesados = 0
        $excluidos = 0
        $convenios = 0
        $ciclosEscolares = 0
        $cuotasMantenimiento = 0
        $noValidos = 0
        
        # Procesar cada linea (saltar encabezado)
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            
            try {
                $fields = $line -split '","' | ForEach-Object { $_ -replace '^"', '' -replace '"$', '' }
                
                if ($fields.Count -lt 13) {
                    Write-Log "Linea ${i}: Formato incorrecto, saltando" "WARN"
                $noValidos++
                $registrosNoProcesados += "`"$($fields[0])`",`"$($fields[1])`",`"$($fields[2])`",`"$($fields[3])`",Formato incorrecto"
                continue
                }
                
                $idsae = $fields[0].Trim()
                $factura = $fields[1].Trim()
                $fechaStr = $fields[2].Trim()
                $observaciones = $fields[3].Trim()
                
                # Parsear fecha de factura
                $fechaFactura = [DateTime]::ParseExact($fechaStr, "dd/MM/yyyy", $null)
                
                # JERARQUIA ESTRICTA A->B->C->D
                $vigencia = $null
                $tipo = ""
                $procesarRegistro = $true
                
                # A. PALABRAS EXCLUIDAS (Prioridad 1 - MAXIMA) - JERARQUIA ESTRICTA
                foreach ($palabra in $config.rules.palabrasProhibidas) {
                    if ($observaciones.ToUpper().Contains($palabra.ToUpper())) {
                        Write-Log "IDSAE $idsae EXCLUIDO por palabra: $palabra" "INFO"
                        $excluidos++
						$registrosNoProcesados += "`"$idsae`",`"$factura`",`"$fechaStr`",`"$observaciones`",Excluido por palabra $palabra"
                        $procesarRegistro = $false
                        break
                    }
                }
                
                if ($procesarRegistro) {
                    # B. CONVENIO (Prioridad 2) - JERARQUIA ESTRICTA
                    $esConvenio = $false
                    # Verificar si el concepto contiene alguna de las palabras de convenio
                    foreach ($palabraConv in $config.rules.palabraConvenio) {
                        if ($observaciones -like "*$palabraConv*") {
                            $esConvenio = $true
                            break
                        }
                    }
                    
                    if ($esConvenio) {
                        $vigencia = $fechaFactura.AddDays($VigenciaConvenio)
                        $tipo = "CONVENIO"
                        $convenios++
                        Write-Log "IDSAE $idsae CONVENIO: $($vigencia.ToString('dd/MM/yyyy'))" "INFO"
                    } else {
                        # Verificar si el concepto contiene alguna de las palabras de ciclo escolar
                        $esCicloEscolar = $false
                        foreach ($palabraCiclo in $config.rules.palabraCicloEscolar) {
                            if ($observaciones -like "*$palabraCiclo*") {
                                $esCicloEscolar = $true
                                break
                            }
                        }
                        
                        if ($esCicloEscolar) {
                            $vigencia = $fechaFactura.AddDays($VigenciaCicloEscolar)
                            $tipo = "CICLO ESCOLAR"
                            $ciclosEscolares++
                            Write-Log "IDSAE $idsae CICLO ESCOLAR: $($vigencia.ToString('dd/MM/yyyy'))" "INFO"
                        } else {
                            # D. CUOTA DE MANTENIMIENTO (Prioridad 4 - MINIMA) - JERARQUIA ESTRICTA
                            $esCuotaMantenimiento = $false
                            
                            if ($observaciones.ToUpper().Contains("CUOTA") -or $observaciones.ToUpper().Contains("MANTENIMIENTO")) {
                                $esCuotaMantenimiento = $true
                            }
                            
                            if ($esCuotaMantenimiento) {
                                $vigenciaCalculada = Calculate-VigenciaCuotaMantenimiento -Observaciones $observaciones -FechaFactura $fechaFactura -VigenciaDia $VigenciaDia
                                if ($vigenciaCalculada) {
                                    $vigencia = $vigenciaCalculada
                                    $tipo = "CUOTA MANTENIMIENTO"
                                    $cuotasMantenimiento++
                                    Write-Log "IDSAE $idsae CUOTA MANTENIMIENTO: $($vigencia.ToString('dd/MM/yyyy'))" "INFO"
                                } else {
                                    Write-Log "IDSAE ${idsae}: No se pudo calcular vigencia CUOTA MANTENIMIENTO - datos insuficientes" "WARN"
                                    $noValidos++
									$registrosNoProcesados += "`"$idsae`",`"$factura`",`"$fechaStr`",`"$observaciones`",No se pudo calcular vigencia Anio o Mes no valido CUOTA MANTENIMIENTO"
                                    $procesarRegistro = $false
                                }
                            } else {
                                # No cumple ninguna jerarquia - no procesar
                                Write-Log "IDSAE ${idsae}: No cumple ninguna jerarquia de vigencias" "WARN"
                                $noValidos++
								$registrosNoProcesados += "`"$idsae`",`"$factura`",`"$fechaStr`",`"$observaciones`",No cumple ninguna jerarquia de vigencias"
                                $procesarRegistro = $false
                            }
                        }
                    }
                }
                
                # Procesar vigencia si es valida
                if ($procesarRegistro -and $vigencia) {
                    $vigenciaStr = Format-DateForMySQL $vigencia
                    
                    # Mantener solo la vigencia mayor por IDSAE
                    if ($vigenciasPorIDSAE.ContainsKey($idsae)) {
                        try {
                            $vigenciaExistente = Parse-DateFromMySQL $vigenciasPorIDSAE[$idsae]
                            
                            if ($vigencia -gt $vigenciaExistente) {
                                $vigenciasPorIDSAE[$idsae] = $vigenciaStr
                                Write-Log "IDSAE $idsae vigencia actualizada: $(Format-DateForMySQL $vigenciaExistente) -> $vigenciaStr" "INFO"
                            } else {
                                Write-Log "IDSAE $idsae vigencia mantenida: $(Format-DateForMySQL $vigenciaExistente) (mayor que $vigenciaStr)" "INFO"
                            }
                        } catch {
                            # Si hay error parseando la existente, usar la nueva
                            $vigenciasPorIDSAE[$idsae] = $vigenciaStr
                            Write-Log "IDSAE $idsae vigencia reemplazada por error de parseo" "WARN"
                        }
                    } else {
                        $vigenciasPorIDSAE[$idsae] = $vigenciaStr
                    }
                    
                    # Agregar a log de procesados
                    $registrosProcesados += "`"$idsae`",`"$factura`",`"$fechaStr`",`"$observaciones`",`"$vigenciaStr`",`"$tipo`""
                    $procesados++
                }
            }
            catch {
                Write-Log "Error procesando linea $i`: $($_.Exception.Message)" "ERROR"
                $noValidos++
				$registrosNoProcesados += "`"$idsae`",`"$factura`",`"$fechaStr`",`"$observaciones`",Error: $($_.Exception.Message)"
				continue
            }
        }
        
        # Escribir archivo de registros procesados
        $procesadosFile = Join-Path $OutputPath "Registros_Procesados.txt"
        $registrosProcesados | Out-File -FilePath $procesadosFile -Encoding UTF8
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Procesamiento completado en $($elapsed.TotalMinutes.ToString('F2')) minutos" "SUCCESS"
        Write-Log "Resumen: $procesados procesados, $excluidos excluidos, $convenios convenios, $ciclosEscolares ciclos escolares, $cuotasMantenimiento cuotas mantenimiento, $noValidos no validos" "SUCCESS"
        Write-Log "Vigencias unicas por IDSAE: $($vigenciasPorIDSAE.Count)" "SUCCESS"
        Write-Log "Archivo generado: $procesadosFile" "SUCCESS"
        
		# Escribir archivo de registros no procesados
        $noProcesadosFile = Join-Path $OutputPath "Registros_no_procesados.txt"
        $registrosNoProcesados | Out-File -FilePath $noProcesadosFile -Encoding UTF8
        $archivosGenerados += $noProcesadosFile
        Write-Log "Archivo generado: $noProcesadosFile" "SUCCESS"
        Write-Log "Total registros no procesados: $($registrosNoProcesados.Count - 1)" "INFO"
		
        # Estabilizacion post-procesamiento
        Write-Log "Estabilizando datos post-procesamiento (8 segundos)..." "INFO"
        Start-Sleep -Seconds 8
        
        return @{
            success = $true
            message = "Vigencias procesadas exitosamente"
            vigencias_calculadas = $vigenciasPorIDSAE.Count
            archivo_procesados = $procesadosFile
            vigencias_data = $vigenciasPorIDSAE
            idsae_procesados = @($vigenciasPorIDSAE.Keys)
            tiempo_total = $elapsed.TotalMinutes.ToString('F2')
            estadisticas = @{
                procesados = $procesados
                excluidos = $excluidos
                convenios = $convenios
                ciclos_escolares = $ciclosEscolares
                cuotas_mantenimiento = $cuotasMantenimiento
                no_validos = $noValidos
            }
        }
    }
    catch {
        Write-Log "Error procesando vigencias: $($_.Exception.Message)" "ERROR"
        return @{
            success = $false
            error = $_.Exception.Message
            vigencias_data = @{}
            idsae_procesados = @()
        }
    }
}

# Funcion OPTIMIZADA para actualizar vigencias en MySQL (BULK UPDATE)
function Update-VigenciasMySQL {
    param([hashtable]$VigenciasData)
    
    $startTime = Get-Date
    $config = Load-Config
    
    try {
        Write-Log "Iniciando actualizacion masiva de vigencias en MySQL" "INFO"
        Write-Log "Vigencias a procesar: $($VigenciasData.Count)" "INFO"
        
        if ($VigenciasData.Count -eq 0) {
            Write-Log "No hay vigencias para actualizar" "WARN"
            return @{
                success = $true
                message = "No hay vigencias para actualizar"
                actualizados = 0
                tiempo_total = "0.00"
            }
        }
        
        # Estabilizacion pre-actualizacion
        Write-Log "Estabilizando conexiones pre-actualizacion (10 segundos)..." "INFO"
        Start-Sleep -Seconds 10
        
        $connectionString = Build-MySQLConnectionString -Config $config.mysql
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        # Crear tabla temporal para vigencias
        Write-Log "Creando tabla temporal para actualizacion masiva..." "INFO"
        $createTempTableSQL = @"
CREATE TEMPORARY TABLE temp_vigencias_update (
    IDSAE VARCHAR(50) PRIMARY KEY,
    Vigencia VARCHAR(50) NOT NULL
) ENGINE=MEMORY
"@
        
        $mysqlCmd = $conn.CreateCommand()
        $mysqlCmd.CommandText = $createTempTableSQL
        $mysqlCmd.ExecuteNonQuery()
        Write-Log "Tabla temporal temp_vigencias_update creada" "SUCCESS"
        
        # Insertar vigencias en lotes a tabla temporal
        Write-Log "Insertando vigencias en tabla temporal..." "INFO"
        $batchSize = 500
        $vigenciasArray = @($VigenciasData.GetEnumerator())
        $totalBatches = [math]::Ceiling($vigenciasArray.Count / $batchSize)
        
        for ($i = 0; $i -lt $vigenciasArray.Count; $i += $batchSize) {
            $batch = $vigenciasArray[$i..([math]::Min($i + $batchSize - 1, $vigenciasArray.Count - 1))]
            $batchNumber = [math]::Floor($i / $batchSize) + 1
            
            $values = @()
            foreach ($item in $batch) {
                $idsae = $item.Key -replace "'", "''"
                $vigencia = $item.Value -replace "'", "''"
                $values += "('$idsae', '$vigencia')"
            }
            
            $insertSQL = "INSERT INTO temp_vigencias_update (IDSAE, Vigencia) VALUES " + ($values -join ", ")
            
            $mysqlCmd.CommandText = $insertSQL
            $mysqlCmd.ExecuteNonQuery()
            
            Write-Log "Lote $batchNumber/$totalBatches insertado: $($batch.Count) vigencias" "INFO"
        }
        
        Write-Log "Todas las vigencias insertadas en tabla temporal" "SUCCESS"
        
        # Ejecutar actualizacion masiva con JOIN
        Write-Log "Ejecutando actualizacion masiva con JOIN..." "INFO"
        $updateSQL = @"
UPDATE Asociado a
INNER JOIN temp_vigencias_update t ON a.IDSAE = t.IDSAE
SET a.Vigencia = t.Vigencia, a.ValidaVigencia = 0
WHERE (
    a.Vigencia IS NULL 
    OR a.Vigencia = '' 
    OR STR_TO_DATE(t.Vigencia, '%d/%m/%Y') > STR_TO_DATE(a.Vigencia, '%d/%m/%Y')
    OR (a.Vigencia NOT LIKE '%/%/%' AND t.Vigencia LIKE '%/%/%')
)
"@
        
        $mysqlCmd.CommandText = $updateSQL
        $rowsUpdated = $mysqlCmd.ExecuteNonQuery()
        
        Write-Log "Actualizacion masiva completada: $rowsUpdated registros actualizados" "SUCCESS"
        
        # Limpiar tabla temporal
        $mysqlCmd.CommandText = "DROP TEMPORARY TABLE temp_vigencias_update"
        $mysqlCmd.ExecuteNonQuery()
        Write-Log "Tabla temporal eliminada" "SUCCESS"
        
        $conn.Close()
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Actualizacion masiva MySQL completada en $($elapsed.TotalMinutes.ToString('F2')) minutos" "SUCCESS"
        
        # Estabilizacion post-actualizacion
        Write-Log "Estabilizando finalizacion (5 segundos)..." "INFO"
        Start-Sleep -Seconds 5
        
        return @{
            success = $true
            message = "Vigencias actualizadas masivamente"
            actualizados = $rowsUpdated
            tiempo_total = $elapsed.TotalMinutes.ToString('F2')
        }
    }
    catch {
        Write-Log "Error en actualizacion masiva MySQL: $($_.Exception.Message)" "ERROR"
        
        if ($conn -and $conn.State -eq [System.Data.ConnectionState]::Open) {
            try {
                # Intentar limpiar tabla temporal en caso de error
                $mysqlCmd.CommandText = "DROP TEMPORARY TABLE IF EXISTS temp_vigencias_update"
                $mysqlCmd.ExecuteNonQuery()
                $conn.Close()
            }
            catch {
                Write-Log "Error limpiando recursos: $($_.Exception.Message)" "WARN"
            }
        }
        
        return @{
            success = $false
            error = $_.Exception.Message
            actualizados = 0
        }
    }
}

# Funcion CORREGIDA para generar archivo Carga_Integra32 con filtrado por IDSAE procesados
function Generate-CargaIntegra32 {
    param(
        [string]$OutputPath,
        [array]$IDSAEProcesados
    )
    
    $startTime = Get-Date
    $config = Load-Config
    
    try {
        Write-Log "Generando archivo Carga_Integra32.txt (solo IDSAE procesados)" "INFO"
        Write-Log "Filtrando por $($IDSAEProcesados.Count) IDSAE procesados en esta ejecucion" "INFO"
        
        if ($IDSAEProcesados.Count -eq 0) {
            Write-Log "No hay IDSAE procesados para generar Carga_Integra32" "WARN"
            return @{
                success = $true
                message = "No hay IDSAE procesados para Carga_Integra32"
                records_count = 0
                output_file = ""
            }
        }
        
        $connectionString = Build-MySQLConnectionString -Config $config.mysql
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        # Construir clausula IN de forma segura para filtrar por IDSAE procesados
        $idsaeList = $IDSAEProcesados | ForEach-Object { "'$($_ -replace "'", "''")'" }
        $idsaeInClause = $idsaeList -join ","
        
        $query = @"
SELECT t.Identificador as CardNumber, a.Vigencia 
FROM Tags t 
INNER JOIN Asociado a ON t.IDSAE = a.IDSAE 
WHERE t.Activa = 0 
AND a.Vigencia IS NOT NULL 
AND a.Vigencia != ''
AND t.IDSAE IN ($idsaeInClause)
ORDER BY t.IDTags
"@
        
        Write-Log "Ejecutando consulta con filtro de $($IDSAEProcesados.Count) IDSAE..." "INFO"
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $reader = $cmd.ExecuteReader()
        
        $cargaFile = Join-Path $OutputPath "Carga_Integra32.txt"
        $csvContent = @()
        $csvContent += "CardNumber,NIVEL ACCESO,FECHA EXPIRACION,"
        
        $recordCount = 0
        while ($reader.Read()) {
            $cardNumber = $reader["CardNumber"].ToString().Trim()
            $vigenciaStr = $reader["Vigencia"].ToString().Trim()
            
            # Crear lista de IDSAE para filtro SQL
            $idsaeList = ($IDSAEProcesados | ForEach-Object { "'$_'" }) -join ","
            
            if ($idsaeList -eq "") {
                Write-Log "No hay IDSAE procesados para generar Carga_Integra32.txt" "WARN"
                return @{ success = $false; error = "No hay IDSAE procesados" }
            }
            
            # Parsear y reformatear fecha para asegurar formato dd/MM/yyyy
            $vigenciaDate = Parse-DateFromMySQL $vigenciaStr
            if ($vigenciaDate) {
                $vigenciaFormateada = Format-DateForMySQL $vigenciaDate
                $csvContent += "$cardNumber,1,$vigenciaFormateada,"
                $recordCount++
            } else {
                Write-Log "Error parseando vigencia para CardNumber $cardNumber`: $vigenciaStr" "WARN"
            }
        }
        
        $reader.Close()
        $conn.Close()
        
        # Escribir archivo
        $csvContent | Out-File -FilePath $cargaFile -Encoding UTF8
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Archivo Carga_Integra32.txt generado: $recordCount registros en $($elapsed.TotalSeconds.ToString('F2')) segundos" "SUCCESS"
        Write-Log "Archivo generado: $cargaFile" "SUCCESS"
        Write-Log "Solo incluye pagos de SAE procesados en esta ejecucion" "INFO"
        
        return @{
            success = $true
            message = "Archivo Carga_Integra32 generado exitosamente"
            records_count = $recordCount
            output_file = $cargaFile
            tiempo_total = $elapsed.TotalSeconds.ToString('F2')
        }
    }
    catch {
        Write-Log "Error generando Carga_Integra32: $($_.Exception.Message)" "ERROR"
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# Funcion para generar archivo Carga_Integra32 con TODOS los IDSAE (según switch activo)
function Generate-CargaIntegra32_All {
    param(
        [string]$OutputPath
    )

    $startTime = Get-Date
    $config = Load-Config

    try {
        Write-Log "Generando archivo Carga_Integra32.txt (Con pagos de SAE y Pagina Web)" "INFO"

        # Fecha de hoy para el filtro
        $today = Get-Date -Format "yyyy-MM-dd"

        $query = @"
SELECT t.Identificador as CardNumber, a.Vigencia 
FROM Tags t
INNER JOIN Asociado a ON t.IDSAE = a.IDSAE
WHERE t.Activa = 0
AND a.Vigencia IS NOT NULL 
AND a.Vigencia != ''
AND STR_TO_DATE(a.Vigencia, '%d/%m/%Y') > STR_TO_DATE('$today', '%Y-%m-%d')
ORDER BY t.IDTags
"@

        $connectionString = Build-MySQLConnectionString -Config $config.mysql
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $reader = $cmd.ExecuteReader()

        $cargaFile = Join-Path $OutputPath "Carga_Integra32.txt"
        $csvContent = @()
        $csvContent += "CardNumber,NIVEL ACCESO,FECHA EXPIRACION,"

        $recordCount = 0
        while ($reader.Read()) {
            $cardNumber = $reader["CardNumber"].ToString().Trim()
            $vigenciaStr = $reader["Vigencia"].ToString().Trim()

            $vigenciaDate = Parse-DateFromMySQL $vigenciaStr
            if ($vigenciaDate) {
                $vigenciaFormateada = Format-DateForMySQL $vigenciaDate
                $csvContent += "$cardNumber,1,$vigenciaFormateada,"
                $recordCount++
            } else {
                Write-Log "Error parseando vigencia para CardNumber $cardNumber`: $vigenciaStr" "WARN"
            }
        }

        $reader.Close()
        $conn.Close()

        # Escribir archivo
        $csvContent | Out-File -FilePath $cargaFile -Encoding UTF8

        $elapsed = (Get-Date) - $startTime
        Write-Log "Archivo Carga_Integra32.txt generado: $recordCount registros en $($elapsed.TotalSeconds.ToString('F2')) segundos" "SUCCESS"
        Write-Log "Archivo generado: $cargaFile" "SUCCESS"
        Write-Log "Incluye TODOS los pagos de SAE y Pagina Web" "INFO"

        return @{
            success = $true
            message = "Archivo Carga_Integra32 (ALL) generado exitosamente"
            records_count = $recordCount
            output_file = $cargaFile
            tiempo_total = $elapsed.TotalSeconds.ToString('F2')
        }
    }
    catch {
        Write-Log "Error generando Carga_Integra32 (ALL): $($_.Exception.Message)" "ERROR"
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# Funcion principal de procesamiento completo CORREGIDA
function Process-VigenciasCompleto {
    param([string]$OutputPath, [int]$DiasFacturas, [int]$VigenciaDia, [int]$VigenciaConvenio, [int]$VigenciaCicloEscolar)
    
    $processStartTime = Get-Date
    
    try {
        Write-Log "=== INICIANDO PROCESO COMPLETO DE VIGENCIAS ===" "INFO"
        Write-Log "Parametros: DiasFacturas=$DiasFacturas, VigenciaDia=$VigenciaDia, VigenciaConvenio=$VigenciaConvenio, VigenciaCicloEscolar=$VigenciaCicloEscolar" "INFO"
        Write-Log "FLUJO CORREGIDO: 1.Copia BD -> 2.Sync Clientes -> 3.Export Registros -> 4.Procesar Vigencias -> 5.Update MySQL -> 6.Generar Carga_Integra32" "INFO"
        
        $config = Load-Config
        
        # Paso 1: Copia de base de datos (5% -> 20%)
        Write-Log "Paso 1: Copiando base de datos" "INFO"
        $copyResult = Copy-Database -SourcePath $config.paths.sourceDbPath -DestinationPath $config.paths.localDbPath
        if (-not $copyResult.success) {
            throw "Error en copia de base de datos: $($copyResult.error)"
        }
        
        # Paso 2: Sincronizacion de clientes (25% -> 40%)
        Write-Log "Paso 2: Sincronizando clientes" "INFO"
        $syncResult = Sync-Clientes
        if (-not $syncResult.success) {
            throw "Error en sincronizacion: $($syncResult.error)"
        }
        
        # Paso 3: Exportacion de registros (45% -> 60%)
        Write-Log "Paso 3: Exportando registros" "INFO"
        $exportResult = Export-Registros -OutputPath $OutputPath -DiasFacturas $DiasFacturas
        if (-not $exportResult.success) {
            throw "Error en exportacion: $($exportResult.error)"
        }
        
        # Paso 4: Procesamiento de vigencias con jerarquia estricta (65% -> 75%)
        Write-Log "Paso 4: Procesando vigencias con jerarquia A->B->C->D" "INFO"
        $processResult = Process-VigenciasFromTxt -OutputPath $OutputPath -VigenciaDia $VigenciaDia -VigenciaConvenio $VigenciaConvenio -VigenciaCicloEscolar $VigenciaCicloEscolar
        if (-not $processResult.success) {
            throw "Error en procesamiento: $($processResult.error)"
        }
        
        # Paso 5: Actualizacion masiva MySQL (80% -> 90%)
        Write-Log "Paso 5: Actualizando vigencias en MySQL masivamente" "INFO"
        $updateResult = Update-VigenciasMySQL -VigenciasData $processResult.vigencias_data
        if (-not $updateResult.success) {
            throw "Error actualizando MySQL: $($updateResult.error)"
        }
        
        # Paso 6: Generacion de Carga_Integra32 (95% -> 100%)
        $config = Load-Config
        $todosIdsae = $false
        if ($config.rules.PSObject.Properties.Name -contains "todosIdsae") {
        $todosIdsae = [bool]$config.rules.todosIdsae
        }

        if ($todosIdsae) {
        Write-Log "Paso 6: Generando Carga_Integra32 con con Pagos de SAE y Pagina Web procesados (switch activo)" "INFO"
        $cargaResult = Generate-CargaIntegra32_All -OutputPath $OutputPath
        } else {
        Write-Log "Paso 6: Generando Carga_Integra32 con Pagos de SAE procesados (switch inactivo)" "INFO"
        $cargaResult = Generate-CargaIntegra32 -OutputPath $OutputPath -IDSAEProcesados $processResult.idsae_procesados
        }

        if (-not $cargaResult.success) {
        throw "Error generando Carga_Integra32: $($cargaResult.error)"
    }

        
        # Proceso completado (100%)
        $totalElapsed = (Get-Date) - $processStartTime
        Write-Log "=== PROCESO COMPLETO FINALIZADO ===" "SUCCESS"
        Write-Log "TIEMPO TOTAL: $($totalElapsed.TotalMinutes.ToString('F2')) minutos" "SUCCESS"
        Write-Log "ESTADISTICAS FINALES:" "SUCCESS"
        Write-Log "- Facturas exportadas: $($exportResult.records_count)" "SUCCESS"
        Write-Log "- Vigencias calculadas: $($processResult.vigencias_calculadas)" "SUCCESS"
        Write-Log "- Vigencias actualizadas en MySQL: $($updateResult.actualizados)" "SUCCESS"
        Write-Log "- Registros en Carga_Integra32: $($cargaResult.records_count)" "SUCCESS"
        
        $archivosGenerados = @()
        if ($exportResult.output_file) { $archivosGenerados += $exportResult.output_file }
        if ($processResult.archivo_procesados) { $archivosGenerados += $processResult.archivo_procesados }
        if ($cargaResult.output_file) { $archivosGenerados += $cargaResult.output_file }
        
        return @{
            success = $true
            message = "Proceso completo finalizado exitosamente"
            facturasProcessed = $exportResult.records_count
            vigenciasUpdated = $updateResult.actualizados
            registrosGenerados = $processResult.vigencias_calculadas
            errors = @()
            archivosGenerados = $archivosGenerados
            tiempo_total = $totalElapsed.TotalMinutes.ToString('F2')
            estadisticas = $processResult.estadisticas
        }
    }
    catch {
        $totalElapsed = (Get-Date) - $processStartTime
        Write-Log "=== PROCESO COMPLETO FALLO ===" "ERROR"
        Write-Log "Error: $($_.Exception.Message)" "ERROR"
        Write-Log "Tiempo transcurrido: $($totalElapsed.TotalMinutes.ToString('F2')) minutos" "ERROR"
        
        return @{
            success = $false
            message = $_.Exception.Message
            facturasProcessed = 0
            vigenciasUpdated = 0
            registrosGenerados = 0
            errors = @($_.Exception.Message)
            archivosGenerados = @()
            tiempo_total = $totalElapsed.TotalMinutes.ToString('F2')
        }
    }
}

# Funcion principal
function Main {
    try {
        Write-Log "Iniciando VigenciasProcessor - Operacion: $Operation" "INFO"
        
        # Validar drivers ODBC
        if (-not (Assert-OdbcDrivers)) {
            throw "Drivers ODBC no disponibles"
        }
        
        # Ejecutar operacion solicitada
        $result = switch ($Operation.ToLower()) {
            "test_firebird_connection" {
                $config = Load-Config
                Test-FirebirdConnection -Config $config.firebird
            }
            "test_mysql_connection" {
                $config = Load-Config
                # Usar funcion avanzada si tiene configuracion de charset o SSL
                if (($config.mysql.PSObject.Properties.Name -contains "charset" -and $config.mysql.charset -ne "NONE") -or 
                    ($config.mysql.PSObject.Properties.Name -contains "sslEnabled")) {
                    Test-MySQLConnectionAdvanced -Config $config.mysql
                } else {
                    Test-MySQLConnection -Config $config.mysql
                }
            }
            "copy_database" {
                return Copy-Database -SourcePath $SourcePath -DestinationPath $DestinationPath
            }
            "sync_clientes" {
                return Sync-Clientes
            }
            "export_registros" {
                return Export-Registros -OutputPath $OutputPath -DiasFacturas $DiasFacturas
            }
            "process_vigencias" {
                # Leer configuracion para obtener estado del switch todosIdsae
                $configPath = Join-Path $PSScriptRoot "config.json"
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                $todosIdsae = if ($config.rules.PSObject.Properties.Name -contains "todosIdsae") { 
                    $config.rules.todosIdsae 
                } else { 
                    $false 
                }
                
                Process-VigenciasCompleto -OutputPath $OutputPath -DiasFacturas $DiasFacturas -VigenciaDia $VigenciaDia -VigenciaConvenio $VigenciaConvenio -VigenciaCicloEscolar $VigenciaCicloEscolar
            }
            "get_mysql_charsets" {
                Get-MySQLCharsets
            }
            "test_mysql_connection_advanced" {
                if (-not $config) { throw "Configuracion requerida para test_mysql_connection_advanced" }
                Test-MySQLConnection -Config $config.mysql
            }
            "execute_mysql_query" {
                if (-not $config -or -not $Query) { throw "Configuracion y consulta requeridas para execute_mysql_query" }
                $params = if ($Parameters -ne "[]") { $Parameters | ConvertFrom-Json } else { @() }
                # Usar funcion avanzada si tiene configuracion de charset o SSL
                if (($config.mysql.PSObject.Properties.Name -contains "charset" -and $config.mysql.charset -ne "NONE") -or 
                    ($config.mysql.PSObject.Properties.Name -contains "sslEnabled")) {
                    Invoke-MySQLQueryAdvanced -Config $config.mysql -Query $Query -Parameters $params
                } else {
                    Invoke-MySQLQuery -Config $config.mysql -Query $Query -Parameters $params
                }
            }
            default {
                return @{
                    success = $false
                    error = "Operacion desconocida: $Operation"
                }
            }
        }
        
        # Convertir resultado a JSON y escribir a salida
        Write-Output ($result | ConvertTo-Json -Depth 10 -Compress)
        
        Write-Log "Operacion $Operation completada exitosamente" "SUCCESS"
    }
    catch {
        $errorResult = @{
            success = $false
            error = $_.Exception.Message
            operation = $Operation
            stack_trace = $_.ScriptStackTrace
        }
        
        Write-Output ($errorResult | ConvertTo-Json -Depth 10 -Compress)
        
        Write-Log "Error en operacion $Operation`: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Ejecutar funcion principal
Main

# ===== NUEVAS FUNCIONES AGREGADAS - NO MODIFICAR CODIGO ANTERIOR =====

# Funcion para construir cadena de conexion MySQL avanzada con charset y SSL
function Build-MySQLConnectionStringAdvanced {
    param([PSCustomObject]$Config)
    
    try {
        # Detectar version del driver MySQL ODBC instalado
        $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
        $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"  # Default fallback
        
        if ($drivers -contains "MySQL ODBC 9.4 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.4 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 9.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.0 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 8.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"
        }
        
        $parts = @()
        $parts += "Driver={$mysqlDriver}"
        $parts += "Server=$($Config.host)"
        $parts += "Port=$($Config.port)"
        $parts += "Database=$($Config.database)"
        $parts += "User=$($Config.user)"
        $parts += "Password=$($Config.password)"
        
        # Agregar charset y collation si se especifica
        if ($Config.PSObject.Properties.Name -contains "charset" -and $Config.charset -and $Config.charset -ne "NONE") {
            $parts += "CharSet=$($Config.charset)"
        }
        
        if ($Config.PSObject.Properties.Name -contains "collation" -and $Config.collation -and $Config.collation -ne "NONE") {
            $parts += "Collation=$($Config.collation)"
        }
        
        # Configurar SSL
        if ($Config.PSObject.Properties.Name -contains "sslEnabled" -and $Config.sslEnabled) {
            $parts += "SSLMode=Required"
            $parts += "SSLCert="
            $parts += "SSLKey="
            $parts += "SSLCA="
        } else {
            $parts += "SSLMode=Disabled"
        }
        
        $parts += "Option=3"
        $parts += "ConnectTimeout=30"
        
        $connectionString = ($parts -join ";")
        
        Write-Log "Usando driver MySQL avanzado: $mysqlDriver"
        if ($Config.charset -and $Config.charset -ne "NONE") {
            Write-Log "Charset configurado: $($Config.charset)"
        }
        if ($Config.collation -and $Config.collation -ne "NONE") {
            Write-Log "Collation configurado: $($Config.collation)"
        }
        Write-Log "SSL habilitado: $($Config.sslEnabled)"
        
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion MySQL avanzada: $($_.Exception.Message)"
    }
}

# Funcion para probar conexion MySQL avanzada con charset y SSL
function Test-MySQLConnectionAdvanced {
    param([PSCustomObject]$Config)
    
    $startTime = Get-Date
    
    try {
        Write-Log "Probando conexion MySQL ODBC avanzada con charset y SSL"
        
        $connectionString = Build-MySQLConnectionStringAdvanced -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            $cmd = $conn.CreateCommand()
            
            # Consulta para obtener informacion de charset y collation
            $cmd.CommandText = @"
SELECT 
    NOW() as server_time,
    @@character_set_database as db_charset,
    @@collation_database as db_collation,
    @@version as mysql_version,
    @@ssl_cipher as ssl_cipher
"@
            
            $reader = $cmd.ExecuteReader()
            $result = @{}
            
            if ($reader.Read()) {
                $result.server_time = $reader["server_time"].ToString()
                $result.db_charset = $reader["db_charset"].ToString()
                $result.db_collation = $reader["db_collation"].ToString()
                $result.mysql_version = $reader["mysql_version"].ToString()
                $result.ssl_cipher = if ($reader["ssl_cipher"] -eq [DBNull]::Value) { "No SSL" } else { $reader["ssl_cipher"].ToString() }
            }
            
            $reader.Close()
            $conn.Close()
            
            $elapsed = (Get-Date) - $startTime
            Write-Log "Conexion MySQL avanzada exitosa en $($elapsed.TotalMilliseconds)ms" "SUCCESS"
            Write-Log "Charset BD: $($result.db_charset), Collation BD: $($result.db_collation)" "SUCCESS"
            Write-Log "Version MySQL: $($result.mysql_version)" "SUCCESS"
            Write-Log "SSL: $($result.ssl_cipher)" "SUCCESS"
            
            return @{
                success = $true
                server_time = $result.server_time
                db_charset = $result.db_charset
                db_collation = $result.db_collation
                mysql_version = $result.mysql_version
                ssl_cipher = $result.ssl_cipher
                execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
                method = "PowerShell-ODBC-Advanced"
            }
        }
        else {
            throw "Conexion fallo - Estado: $($conn.State)"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Conexion MySQL avanzada fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
}

# Funcion para ejecutar consulta MySQL avanzada con charset y SSL
function Invoke-MySQLQueryAdvanced {
    param(
        [PSCustomObject]$Config,
        [string]$Query,
        [array]$Parameters = @()
    )
    
    $startTime = Get-Date
    
    try {
        Write-Log "Ejecutando consulta MySQL avanzada con $($Parameters.Count) parametros"
        
        $connectionString = Build-MySQLConnectionStringAdvanced -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        # Configurar charset de sesion si se especifica
        if ($Config.PSObject.Properties.Name -contains "charset" -and $Config.charset -and $Config.charset -ne "NONE") {
            $charsetCmd = $conn.CreateCommand()
            $charsetCmd.CommandText = "SET NAMES $($Config.charset)"
            $charsetCmd.ExecuteNonQuery()
            Write-Log "Charset de sesion configurado: $($Config.charset)"
        }
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query
        
        # Agregar parametros ODBC
        for ($i = 0; $i -lt $Parameters.Count; $i++) {
            $paramValue = if ($Parameters[$i] -eq $null) { [DBNull]::Value } else { $Parameters[$i] }
            $param = $cmd.Parameters.Add("?", [System.Data.Odbc.OdbcType]::VarChar)
            $param.Value = $paramValue
        }
        
        $reader = $cmd.ExecuteReader()
        $dataTable = New-Object System.Data.DataTable
        $dataTable.Load($reader)
        $reader.Close()
        $conn.Close()
        
        # Convertir resultados a formato JSON serializable
        $resultData = @()
        if ($dataTable.Rows.Count -gt 0) {
            foreach ($row in $dataTable.Rows) {
                $rowObj = @{}
                foreach ($column in $dataTable.Columns) {
                    $value = $row[$column.ColumnName]
                    if ($value -is [DateTime]) {
                        $rowObj[$column.ColumnName] = $value.ToString("yyyy-MM-ddTHH:mm:ss")
                    }
                    elseif ($value -is [DBNull]) {
                        $rowObj[$column.ColumnName] = $null
                    }
                    else {
                        $rowObj[$column.ColumnName] = $value
                    }
                }
                $resultData += $rowObj
            }
        }
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Consulta MySQL avanzada ejecutada exitosamente: $($resultData.Count) filas en $($elapsed.TotalMilliseconds)ms" "SUCCESS"
        
        return @{
            success = $true
            data = $resultData
            rows_count = $resultData.Count
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Consulta MySQL avanzada fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
            data = @()
            rows_count = 0
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
}

# ===== NUEVAS FUNCIONES AGREGADAS - NO MODIFICAR CODIGO EXISTENTE =====

# Funcion para construir cadena de conexion MySQL avanzada con charset y SSL
function Build-MySQLConnectionStringAdvanced {
    param([PSCustomObject]$Config)
    
    try {
        # Detectar version del driver MySQL ODBC instalado
        $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
        $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"  # Default fallback
        
        if ($drivers -contains "MySQL ODBC 9.4 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.4 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 9.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 9.0 Unicode Driver"
        } elseif ($drivers -contains "MySQL ODBC 8.0 Unicode Driver") {
            $mysqlDriver = "MySQL ODBC 8.0 Unicode Driver"
        }
        
        $parts = @()
        $parts += "Driver={$mysqlDriver}"
        $parts += "Server=$($Config.host)"
        $parts += "Port=$($Config.port)"
        $parts += "Database=$($Config.database)"
        $parts += "User=$($Config.user)"
        $parts += "Password=$($Config.password)"
        
        # Configuracion de charset si esta especificado
        if ($Config.PSObject.Properties.Name -contains "charset" -and $Config.charset -and $Config.charset -ne "NONE") {
            $parts += "CharSet=$($Config.charset)"
        }
        
        # Configuracion SSL
        if ($Config.PSObject.Properties.Name -contains "sslEnabled" -and $Config.sslEnabled -eq $true) {
            $parts += "SSLMode=Required"
        } else {
            $parts += "SSLMode=Disabled"
        }
        
        $parts += "Option=3"
        
        $connectionString = ($parts -join ";")
        
        Write-Log "Usando driver MySQL avanzado: $mysqlDriver" "INFO"
        Write-Log "Charset configurado: $($Config.charset)" "INFO"
        Write-Log "SSL habilitado: $($Config.sslEnabled)" "INFO"
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion MySQL avanzada: $($_.Exception.Message)"
    }
}

# Funcion para probar conexion MySQL con configuracion avanzada
function Test-MySQLConnectionAdvanced {
    param([PSCustomObject]$Config)
    
    $startTime = Get-Date
    $conn = $null
    
    try {
        Write-Log "Probando conexion MySQL ODBC con configuracion avanzada" "INFO"
        
        $connectionString = Build-MySQLConnectionStringAdvanced -Config $Config
        Write-Log "Cadena de conexion: $($connectionString -replace 'Password=[^;]*', 'Password=***')" "INFO"
        
        $conn = New-Object System.Data.Odbc.OdbcConnection
        $conn.ConnectionString = $connectionString
        $conn.ConnectionTimeout = 30
        
        Write-Log "Intentando abrir conexion MySQL avanzada..." "INFO"
        $conn.Open()
        
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            Write-Log "Conexion abierta exitosamente, probando consulta..." "INFO"
            
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT NOW() as server_time, @@character_set_database as charset, @@have_ssl as ssl_support"
            $cmd.CommandTimeout = 10
            $reader = $cmd.ExecuteReader()
            
            $serverTime = ""
            $charset = ""
            $sslSupport = ""
            
            if ($reader.Read()) {
                $serverTime = $reader["server_time"].ToString()
                $charset = $reader["charset"].ToString()
                $sslSupport = $reader["ssl_support"].ToString()
            }
            $reader.Close()
            
            $elapsed = (Get-Date) - $startTime
            Write-Log "Conexion MySQL avanzada exitosa en $($elapsed.TotalMilliseconds)ms" "SUCCESS"
            Write-Log "Tiempo servidor: $serverTime, Charset: $charset, SSL: $sslSupport" "SUCCESS"
            
            return @{
                success = $true
                server_time = $serverTime
                charset = $charset
                ssl_support = $sslSupport
                execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
                method = "PowerShell-ODBC-Advanced"
                driver_version = $mysqlDriver
            }
        }
        else {
            throw "Conexion fallo - Estado: $($conn.State)"
        }
    }
    catch [System.Data.Odbc.OdbcException] {
        $elapsed = (Get-Date) - $startTime
        $odbcEx = $_.Exception
        
        Write-Log "OdbcException MySQL avanzada despues de $($elapsed.TotalMilliseconds)ms" "ERROR"
        Write-Log "Mensaje: $($odbcEx.Message)" "ERROR"
        Write-Log "Codigo de error: $($odbcEx.ErrorCode)" "ERROR"
        
        return @{
            success = $false
            error = $odbcEx.Message
            error_code = $odbcEx.ErrorCode
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Conexion MySQL avanzada fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
    finally {
        if ($conn -and $conn.State -eq [System.Data.ConnectionState]::Open) {
            try {
                $conn.Close()
                Write-Log "Conexion MySQL avanzada cerrada correctamente" "INFO"
            }
            catch {
                Write-Log "Error cerrando conexion MySQL avanzada: $($_.Exception.Message)" "WARN"
            }
        }
    }
}

# Funcion para ejecutar consulta MySQL con configuracion avanzada
function Invoke-MySQLQueryAdvanced {
    param(
        [PSCustomObject]$Config,
        [string]$Query,
        [array]$Parameters = @()
    )
    
    $startTime = Get-Date
    $conn = $null
    
    try {
        Write-Log "Ejecutando consulta MySQL ODBC avanzada con $($Parameters.Count) parametros" "INFO"
        
        $connectionString = Build-MySQLConnectionStringAdvanced -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query
        $cmd.CommandTimeout = 60
        
        # Agregar parametros ODBC
        for ($i = 0; $i -lt $Parameters.Count; $i++) {
            $paramValue = if ($Parameters[$i] -eq $null) { [DBNull]::Value } else { $Parameters[$i] }
            $param = $cmd.Parameters.Add("?", [System.Data.Odbc.OdbcType]::VarChar)
            $param.Value = $paramValue
        }
        
        $reader = $cmd.ExecuteReader()
        $dataTable = New-Object System.Data.DataTable
        $dataTable.Load($reader)
        $reader.Close()
        
        # Convertir resultados a formato JSON serializable
        $resultData = @()
        if ($dataTable.Rows.Count -gt 0) {
            foreach ($row in $dataTable.Rows) {
                $rowObj = @{}
                foreach ($column in $dataTable.Columns) {
                    $value = $row[$column.ColumnName]
                    if ($value -is [DateTime]) {
                        $rowObj[$column.ColumnName] = $value.ToString("yyyy-MM-ddTHH:mm:ss")
                    }
                    elseif ($value -is [DBNull]) {
                        $rowObj[$column.ColumnName] = $null
                    }
                    else {
                        $rowObj[$column.ColumnName] = $value
                    }
                }
                $resultData += $rowObj
            }
        }
        
        $elapsed = (Get-Date) - $startTime
        Write-Log "Consulta MySQL ODBC avanzada ejecutada exitosamente: $($resultData.Count) filas en $($elapsed.TotalMilliseconds)ms" "SUCCESS"
        
        return @{
            success = $true
            data = $resultData
            rows_count = $resultData.Count
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Consulta MySQL ODBC avanzada fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
            data = @()
            rows_count = 0
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-Advanced"
        }
    }
    finally {
        if ($conn -and $conn.State -eq [System.Data.ConnectionState]::Open) {
            try {
                $conn.Close()
                Write-Log "Conexion MySQL avanzada cerrada correctamente" "INFO"
            }
            catch {
                Write-Log "Error cerrando conexion MySQL avanzada: $($_.Exception.Message)" "WARN"
            }
        }
    }
}