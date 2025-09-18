# FirebirdBridge.ps1
# Interface de Gestion para Vigencias - Migrado a ODBC
# PowerShell 5.1 + System.Data.Odbc (sin DLLs externas)

param(
    [Parameter(Mandatory=$true)]
    [string]$Operation,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigJson = "{}",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigJsonPath = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Query = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Parameters = "[]"
)

# Configurar encoding para caracteres especiales
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Variables globales
$scriptRoot = Split-Path -Parent $PSCommandPath

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
            # Mostrar drivers disponibles para debug
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
            # Mostrar drivers disponibles para debug
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

# Funcion para construir cadena de conexion Firebird ODBC compatible con SAE 9
function Build-FirebirdConnectionString {
    param([PSCustomObject]$Config)
    
    try {
        # Usar driver configurado o default
        $firebirdDriver = if ($Config.PSObject.Properties.Name -contains "odbcDriverName" -and $Config.odbcDriverName) { 
            $Config.odbcDriverName 
        } else { 
            "Firebird/InterBase(r) driver" 
        }
        
        # Verificar que el driver existe
        $drivers = Get-OdbcDriver | Select-Object -ExpandProperty Name
        if ($drivers -contains $firebirdDriver) {
            Write-Log "Usando driver: $firebirdDriver" "INFO"
        } else {
            Write-Log "Driver no encontrado: $firebirdDriver, usando default" "WARN"
            $firebirdDriver = "Firebird/InterBase(r) driver"
        }
        
        $dbPath = ""
        if ($Config.PSObject.Properties.Name -contains "databasePath" -and $Config.databasePath) {
            $dbPath = $Config.databasePath
        } elseif ($Config.PSObject.Properties.Name -contains "database" -and $Config.database) {
            $dbPath = $Config.database
        } else {
            throw "No se especifico la ruta de la base de datos"
        }
        
        # Validar que el archivo de base de datos existe
        if (-not (Test-Path $dbPath)) {
            Write-Log "Advertencia: Archivo de base de datos no encontrado: $dbPath" "WARN"
        }
        
        # Configuracion especifica para SAE 9 Firebird 2.5
        $parts = @()
        $parts += "Driver={$firebirdDriver}"
        $parts += "Dbname=$dbPath"
        $parts += "Uid=$($Config.user)"
        $parts += "Pwd=$($Config.password)"
        
        # Usar charset configurado
        $charset = if ($Config.PSObject.Properties.Name -contains "clientCharset" -and $Config.clientCharset) { 
            $Config.clientCharset 
        } else { 
            "WIN1252" 
        }
        $parts += "CharSet=$charset"
        
        # Usar dialecto configurado
        $dialect = if ($Config.PSObject.Properties.Name -contains "dialect" -and $Config.dialect) { 
            $Config.dialect 
        } else { 
            3 
        }
        $parts += "Dialect=$dialect"
        
        $parts += "ReadOnly=0"
        $parts += "NoWait=0"
        
        $connectionString = ($parts -join ";")
        
        Write-Log "Cadena de conexion Firebird SAE 9 construida - Driver: $firebirdDriver, Charset: $charset, Dialect: $dialect" "INFO"
        Write-Log "Base de datos: $dbPath" "INFO"
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion Firebird: $($_.Exception.Message)"
    }
}

# Funcion para construir cadena de conexion MySQL ODBC
function Build-MySQLConnectionString {
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
        
        # Construir partes de conexion basicas
        $parts = @(
            "Driver={$mysqlDriver}",
            "Server=$($Config.host)",
            "Port=$($Config.port)",
            "Database=$($Config.database)",
            "User=$($Config.user)",
            "Password=$($Config.password)"
        )
        
        # Agregar charset si esta configurado
        if ($Config.PSObject.Properties.Name -contains "charset" -and $Config.charset) {
            $parts += "Charset=$($Config.charset)"
        }
        
        # Configuracion SSL
        if ($Config.PSObject.Properties.Name -contains "sslEnabled" -and $Config.sslEnabled) {
            $sslMode = if ($Config.PSObject.Properties.Name -contains "sslMode" -and $Config.sslMode) { 
                $Config.sslMode 
            } else { 
                "PREFERRED" 
            }
            $parts += "SSLMode=$sslMode"
            
            # Agregar rutas de certificados SSL si estan configuradas
            if ($Config.PSObject.Properties.Name -contains "sslCertPath" -and $Config.sslCertPath -and (Test-Path $Config.sslCertPath)) {
                $parts += "SSLCert=$($Config.sslCertPath)"
            }
            
            if ($Config.PSObject.Properties.Name -contains "sslKeyPath" -and $Config.sslKeyPath -and (Test-Path $Config.sslKeyPath)) {
                $parts += "SSLKey=$($Config.sslKeyPath)"
            }
            
            if ($Config.PSObject.Properties.Name -contains "sslCAPath" -and $Config.sslCAPath -and (Test-Path $Config.sslCAPath)) {
                $parts += "SSLCA=$($Config.sslCAPath)"
            }
        } else {
            $parts += "SSLMode=DISABLED"
        }
        
        # Opciones adicionales
        $parts += @(
            "Option=3"
        )
        
        $connectionString = $parts -join ";"
        
        $charset = if ($Config.PSObject.Properties.Name -contains "charset") { $Config.charset } else { "default" }
        $sslStatus = if ($Config.PSObject.Properties.Name -contains "sslEnabled" -and $Config.sslEnabled) { "habilitado" } else { "deshabilitado" }
        
        Write-Log "Cadena de conexion MySQL construida - Driver: $mysqlDriver, Charset: $charset, SSL: $sslStatus" "INFO"
        return $connectionString
    }
    catch {
        throw "Error construyendo cadena de conexion MySQL: $($_.Exception.Message)"
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
        
        # Crear conexion ODBC
        $conn = New-Object System.Data.Odbc.OdbcConnection
        $conn.ConnectionString = $connectionString
        
        # Aplicar timeout configurado
        $timeout = if ($Config.PSObject.Properties.Name -contains "connectionTimeout" -and $Config.connectionTimeout) { 
            $Config.connectionTimeout 
        } else { 
            30 
        }
        $conn.ConnectionTimeout = $timeout
        
        Write-Log "Intentando abrir conexion..." "INFO"
        $conn.Open()
        
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            Write-Log "Conexion abierta exitosamente, probando consulta..." "INFO"
            
            # Probar consulta simple especifica para Firebird 2.5
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT CURRENT_TIMESTAMP FROM RDB`$DATABASE"
            $cmd.CommandTimeout = 10
            $result = $cmd.ExecuteScalar()
            
            $elapsed = (Get-Date) - $startTime
            $charset = if ($Config.PSObject.Properties.Name -contains "clientCharset") { $Config.clientCharset } else { "WIN1252" }
            $dialect = if ($Config.PSObject.Properties.Name -contains "dialect") { $Config.dialect } else { 3 }
            Write-Log "Conexion Firebird SAE 9 exitosa en $($elapsed.TotalMilliseconds)ms - Charset: $charset, Dialect: $dialect, Tiempo servidor: $result" "SUCCESS"
            
            return @{
                success = $true
                server_time = $result.ToString()
                execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
                method = "PowerShell-ODBC-2.0.5.156"
                driver_version = "Firebird ODBC 2.0.5.156"
                charset = $charset
                dialect = $dialect
            }
        }
        else {
            throw "Conexion fallo - Estado: $($conn.State)"
        }
    }
    catch [System.Data.Odbc.OdbcException] {
        $elapsed = (Get-Date) - $startTime
        $odbcEx = $_.Exception
        
        Write-Log "OdbcException capturada despues de $($elapsed.TotalMilliseconds)ms" "ERROR"
        Write-Log "Mensaje principal: $($odbcEx.Message)" "ERROR"
        Write-Log "Codigo de error: $($odbcEx.ErrorCode)" "ERROR"
        Write-Log "Estado SQL: $($odbcEx.Source)" "ERROR"
        
        # Iterar sobre todos los errores ODBC
        if ($odbcEx.Errors -and $odbcEx.Errors.Count -gt 0) {
            Write-Log "Detalles de errores ODBC ($($odbcEx.Errors.Count) errores):" "ERROR"
            for ($i = 0; $i -lt $odbcEx.Errors.Count; $i++) {
                $error = $odbcEx.Errors[$i]
                Write-Log "Error $($i + 1): Mensaje='$($error.Message)' SQLState='$($error.SQLState)' NativeError='$($error.NativeError)'" "ERROR"
            }
        }
        
        return @{
            success = $false
            error = $odbcEx.Message
            error_code = $odbcEx.ErrorCode
            sql_state = if ($odbcEx.Errors.Count -gt 0) { $odbcEx.Errors[0].SQLState } else { "Unknown" }
            native_error = if ($odbcEx.Errors.Count -gt 0) { $odbcEx.Errors[0].NativeError } else { 0 }
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-2.0.5.156"
            odbc_errors = if ($odbcEx.Errors.Count -gt 0) { 
                @($odbcEx.Errors | ForEach-Object { 
                    @{
                        message = $_.Message
                        sql_state = $_.SQLState
                        native_error = $_.NativeError
                    }
                })
            } else { @() }
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Conexion Firebird fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        Write-Log "Tipo de excepcion: $($_.Exception.GetType().Name)" "ERROR"
        
        if ($_.Exception.InnerException) {
            Write-Log "Excepcion interna: $($_.Exception.InnerException.Message)" "ERROR"
        }
        
        return @{
            success = $false
            error = $errorMsg
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC-2.0.5.156"
            exception_type = $_.Exception.GetType().Name
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
    
    try {
        Write-Log "Probando conexion MySQL ODBC"
        
        $connectionString = Build-MySQLConnectionString -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        if ($conn.State -eq [System.Data.ConnectionState]::Open) {
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT NOW() as server_time"
            $result = $cmd.ExecuteScalar()
            
            $conn.Close()
            
            $elapsed = (Get-Date) - $startTime
            Write-Log "Conexion MySQL ODBC exitosa en $($elapsed.TotalMilliseconds)ms - Tiempo servidor: $result" "SUCCESS"
            
            return @{
                success = $true
                server_time = $result.ToString()
                execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
                method = "PowerShell-ODBC"
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
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC"
        }
    }
}

# Funcion para ejecutar consulta Firebird ODBC compatible con SAE 9
function Invoke-FirebirdQuery {
    param(
        [PSCustomObject]$Config,
        [string]$Query,
        [array]$Parameters = @()
    )
    
    $startTime = Get-Date
    
    try {
        Write-Log "Ejecutando consulta Firebird ODBC SAE 9 con $($Parameters.Count) parametros"
        
        $connectionString = Build-FirebirdConnectionString -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query
        $cmd.CommandTimeout = 60
        
        # Agregar parametros ODBC (usar ? en lugar de @param)
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
        Write-Log "Consulta Firebird SAE 9 ODBC ejecutada exitosamente: $($resultData.Count) filas en $($elapsed.TotalMilliseconds)ms" "SUCCESS"
        
        return @{
            success = $true
            data = $resultData
            rows_count = $resultData.Count
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Consulta Firebird SAE 9 ODBC fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
            data = @()
            rows_count = 0
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC"
        }
    }
}

# Funcion para ejecutar consulta MySQL ODBC
function Invoke-MySQLQuery {
    param(
        [PSCustomObject]$Config,
        [string]$Query,
        [array]$Parameters = @()
    )
    
    $startTime = Get-Date
    
    try {
        Write-Log "Ejecutando consulta MySQL ODBC con $($Parameters.Count) parametros"
        
        $connectionString = Build-MySQLConnectionString -Config $Config
        $conn = New-Object System.Data.Odbc.OdbcConnection($connectionString)
        $conn.Open()
        
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Query
        
        # Agregar parametros ODBC (usar ? en lugar de @param)
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
        Write-Log "Consulta MySQL ODBC ejecutada exitosamente: $($resultData.Count) filas en $($elapsed.TotalMilliseconds)ms" "SUCCESS"
        
        return @{
            success = $true
            data = $resultData
            rows_count = $resultData.Count
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC"
        }
    }
    catch {
        $elapsed = (Get-Date) - $startTime
        $errorMsg = $_.Exception.Message
        Write-Log "Consulta MySQL ODBC fallo despues de $($elapsed.TotalMilliseconds)ms: $errorMsg" "ERROR"
        
        return @{
            success = $false
            error = $errorMsg
            data = @()
            rows_count = 0
            execution_time = "$($elapsed.TotalMilliseconds.ToString('F2'))ms"
            method = "PowerShell-ODBC"
        }
    }
}

# Funcion principal
function Main {
    try {
        Write-Log "Iniciando FirebirdBridge SAE 9 - Operacion: $Operation"
        
        # Validar drivers ODBC
        if (-not (Assert-OdbcDrivers)) {
            throw "Drivers ODBC no disponibles"
        }
        
        # Parsear configuracion JSON
        $config = $null
        if ($ConfigJsonPath -and (Test-Path $ConfigJsonPath)) {
            try {
                $configContent = Get-Content $ConfigJsonPath -Raw -Encoding UTF8
                $config = $configContent | ConvertFrom-Json
                Write-Log "Configuracion cargada desde archivo: $ConfigJsonPath"
            } catch {
                throw "Error parseando configuracion desde archivo: $($_.Exception.Message)"
            }
        }
        elseif ($ConfigJson -ne "{}") {
            try {
                # Limpiar el JSON de escapes innecesarios
                $cleanJson = $ConfigJson
                if ($cleanJson.StartsWith('"') -and $cleanJson.EndsWith('"')) {
                    $cleanJson = $cleanJson.Substring(1, $cleanJson.Length - 2)
                }
                $cleanJson = $cleanJson -replace '""', '"'
                $config = $cleanJson | ConvertFrom-Json
                Write-Log "Configuracion JSON parseada exitosamente"
            } catch {
                throw "Error parseando configuracion JSON: $($_.Exception.Message)"
            }
        }
        
        # Ejecutar operacion solicitada
        $result = switch ($Operation.ToLower()) {
            "test_firebird_connection" {
                if (-not $config) { throw "Configuracion requerida para test_firebird_connection" }
                Test-FirebirdConnection -Config $config.firebird
            }
            "test_mysql_connection" {
                if (-not $config) { throw "Configuracion requerida para test_mysql_connection" }
                Test-MySQLConnection -Config $config.mysql
            }
            "execute_firebird_query" {
                if (-not $config -or -not $Query) { throw "Configuracion y consulta requeridas para execute_firebird_query" }
                $params = if ($Parameters -ne "[]") { $Parameters | ConvertFrom-Json } else { @() }
                Invoke-FirebirdQuery -Config $config.firebird -Query $Query -Parameters $params
            }
            "execute_mysql_query" {
                if (-not $config -or -not $Query) { throw "Configuracion y consulta requeridas para execute_mysql_query" }
                $params = if ($Parameters -ne "[]") { $Parameters | ConvertFrom-Json } else { @() }
                Invoke-MySQLQuery -Config $config.mysql -Query $Query -Parameters $params
            }
            default {
                @{
                    success = $false
                    error = "Operacion desconocida: $Operation"
                    method = "PowerShell-ODBC"
                }
            }
        }
        
        # Convertir resultado a JSON y escribir a salida
        Write-Output ($result | ConvertTo-Json -Depth 10 -Compress)
        
        Write-Log "Operacion $Operation completada exitosamente"
    }
    catch {
        $errorResult = @{
            success = $false
            error = $_.Exception.Message
            operation = $Operation
            method = "PowerShell-ODBC"
            stack_trace = $_.ScriptStackTrace
        }
        
        Write-Output ($errorResult | ConvertTo-Json -Depth 10 -Compress)
        
        Write-Log "Error en operacion $Operation`: $($_.Exception.Message)" "ERROR"
        exit 1
    }
}

# Ejecutar funcion principal
Main