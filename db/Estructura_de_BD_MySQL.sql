-- MySQL dump 10.13  Distrib 8.0.19, for Win64 (x86_64)
--
-- Host: bdjhon.chyuseqm2ltf.us-east-2.rds.amazonaws.com    Database: ComunidadDecidida
-- ------------------------------------------------------
-- Server version	8.0.40

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
SET @MYSQLDUMP_TEMP_LOG_BIN = @@SESSION.SQL_LOG_BIN;
SET @@SESSION.SQL_LOG_BIN= 0;

--
-- GTID state at the beginning of the backup 
--

SET @@GLOBAL.GTID_PURGED=/*!80000 '+'*/ '';

--
-- Table structure for table `AltaTAG`
--

DROP TABLE IF EXISTS `AltaTAG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `AltaTAG` (
  `IDAltaTag` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `Etiqueta` varchar(50) DEFAULT NULL,
  `SolicitudAlta` text,
  `FechaAlta` datetime DEFAULT NULL,
  PRIMARY KEY (`IDAltaTag`)
) ENGINE=InnoDB AUTO_INCREMENT=4122 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Asociado`
--

DROP TABLE IF EXISTS `Asociado`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Asociado` (
  `IDAsociado` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `Nombre` varchar(255) DEFAULT NULL,
  `Vigencia` varchar(50) DEFAULT NULL,
  `ValidaVigencia` int DEFAULT NULL,
  PRIMARY KEY (`IDAsociado`),
  UNIQUE KEY `IDSAE` (`IDSAE`)
) ENGINE=InnoDB AUTO_INCREMENT=3059 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `AsociadosSinTag`
--

DROP TABLE IF EXISTS `AsociadosSinTag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `AsociadosSinTag` (
  `IDAsociado` int NOT NULL,
  `IDSAE` int DEFAULT NULL,
  `Nombre` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`IDAsociado`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BitacoraMalUso`
--

DROP TABLE IF EXISTS `BitacoraMalUso`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `BitacoraMalUso` (
  `IDBitacora` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `Tag` varchar(200) NOT NULL,
  `Comentario` varchar(200) DEFAULT NULL,
  `FechaBitacora` varchar(200) DEFAULT NULL,
  `Estado` int NOT NULL,
  PRIMARY KEY (`IDBitacora`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DatosAdicionales`
--

DROP TABLE IF EXISTS `DatosAdicionales`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `DatosAdicionales` (
  `IIDatoAdicional` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `CorreoElectronico` varchar(100) NOT NULL,
  `Telefono` varchar(100) NOT NULL,
  PRIMARY KEY (`IIDatoAdicional`),
  KEY `IDSAE` (`IDSAE`),
  CONSTRAINT `DatosAdicionales_ibfk_1` FOREIGN KEY (`IDSAE`) REFERENCES `Direccion` (`IDSAE`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2419 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Direccion`
--

DROP TABLE IF EXISTS `Direccion`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Direccion` (
  `IDDireccion` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `Calle` varchar(255) DEFAULT NULL,
  `NumInt` varchar(50) DEFAULT NULL,
  `NumExt` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`IDDireccion`),
  KEY `IDSAE` (`IDSAE`),
  CONSTRAINT `Direccion_ibfk_1` FOREIGN KEY (`IDSAE`) REFERENCES `Asociado` (`IDSAE`)
) ENGINE=InnoDB AUTO_INCREMENT=3059 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `DocumentosAltaTAG`
--

DROP TABLE IF EXISTS `DocumentosAltaTAG`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `DocumentosAltaTAG` (
  `IDDocumento` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `ImagenINE` text,
  `ImagenTarjetaCirculacion` text,
  PRIMARY KEY (`IDDocumento`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ErroresProcesamiento`
--

DROP TABLE IF EXISTS `ErroresProcesamiento`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ErroresProcesamiento` (
  `IdError` int NOT NULL AUTO_INCREMENT,
  `Proceso` varchar(100) DEFAULT NULL,
  `MensajeError` text,
  `FechaError` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`IdError`)
) ENGINE=InnoDB AUTO_INCREMENT=144 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `MalUso`
--

DROP TABLE IF EXISTS `MalUso`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `MalUso` (
  `IDMalUso` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `Tag` varchar(200) NOT NULL,
  `URLMalUso` varchar(200) DEFAULT NULL,
  `FechaIncidente` varchar(200) DEFAULT NULL,
  `FechaActivacion` varchar(200) DEFAULT NULL,
  `Estado` int NOT NULL,
  PRIMARY KEY (`IDMalUso`)
) ENGINE=InnoDB AUTO_INCREMENT=31 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ProcesosExitosos`
--

DROP TABLE IF EXISTS `ProcesosExitosos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ProcesosExitosos` (
  `IdProceso` int NOT NULL AUTO_INCREMENT,
  `Proceso` varchar(100) DEFAULT NULL,
  `MensajeExito` text,
  `FechaEjecucion` datetime DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`IdProceso`)
) ENGINE=InnoDB AUTO_INCREMENT=1548 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `ROLE`
--

DROP TABLE IF EXISTS `ROLE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ROLE` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `Name` varchar(50) NOT NULL,
  `Description` varchar(255) NOT NULL,
  `Loevm` tinyint(1) NOT NULL,
  `Fechmov` datetime NOT NULL,
  `Fechact` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Tags`
--

DROP TABLE IF EXISTS `Tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Tags` (
  `IDTags` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int NOT NULL,
  `Identificador` varchar(255) DEFAULT NULL,
  `Etiqueta` varchar(100) DEFAULT NULL,
  `Activa` int DEFAULT NULL,
  `CancelacionWA` varchar(200) DEFAULT NULL,
  `DocCancelacion` varchar(200) DEFAULT NULL,
  `FechaAlta` datetime DEFAULT NULL,
  `FechaActualizacion` datetime DEFAULT NULL,
  `TAGNUEVA` int DEFAULT NULL,
  `Placa` varchar(50) DEFAULT NULL,
  `DocAltaTag` text,
  `Notificado` int DEFAULT NULL,
  PRIMARY KEY (`IDTags`)
) ENGINE=InnoDB AUTO_INCREMENT=4317 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `USUARIO`
--

DROP TABLE IF EXISTS `USUARIO`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `USUARIO` (
  `Id` int NOT NULL AUTO_INCREMENT,
  `FullName` varchar(255) NOT NULL,
  `UserName` varchar(150) NOT NULL,
  `Password` varchar(150) NOT NULL,
  `Role_Id` int NOT NULL,
  `Loevm` tinyint(1) NOT NULL,
  `Fechmov` datetime NOT NULL,
  `Fechact` datetime DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Vigencia`
--

DROP TABLE IF EXISTS `Vigencia`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `Vigencia` (
  `IdVigencia` int NOT NULL AUTO_INCREMENT,
  `IDSAE` int DEFAULT NULL,
  `Concepto` text,
  `Vigencia` varchar(50) DEFAULT NULL,
  `FechaProcesado` datetime DEFAULT NULL,
  PRIMARY KEY (`IdVigencia`)
) ENGINE=InnoDB AUTO_INCREMENT=40260 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `VigenciaIncorrecta`
--

DROP TABLE IF EXISTS `VigenciaIncorrecta`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `VigenciaIncorrecta` (
  `IdVigencia` int NOT NULL AUTO_INCREMENT,
  `IdSAE` int DEFAULT NULL,
  `Concepto` text,
  `Vigencia` varchar(50) DEFAULT NULL,
  `FechaProcesado` datetime DEFAULT NULL,
  PRIMARY KEY (`IdVigencia`)
) ENGINE=InnoDB AUTO_INCREMENT=10667 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping routines for database 'ComunidadDecidida'
--
/*!50003 DROP PROCEDURE IF EXISTS `ActualizarVigenciaAsociado` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `ActualizarVigenciaAsociado`()
BEGIN
	UPDATE Asociado A
    INNER JOIN Vigencia V ON A.IDSAE = V.IDSAE
    SET A.Vigencia = V.Vigencia;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `GetTagByAsociadoIdAndEtiqueta` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `GetTagByAsociadoIdAndEtiqueta`(
    IN p_IDSAE INT,
    IN p_Etiqueta VARCHAR(100),
    IN p_Identificador VARCHAR(100)
)
BEGIN
    -- Primera condición: p_Etiqueta es 'APP'
    IF p_Etiqueta = 'APP' THEN
        SELECT IDTags, IDSAE, Identificador, Etiqueta, Activa, CancelacionWA, DocCancelacion, TAGNUEVA, Placa, DocAltaTAG
        FROM Tags
        WHERE Etiqueta = p_Etiqueta AND Identificador = p_Identificador;

    -- Segunda condición: p_Etiqueta es un string numérico de al menos 9 caracteres
    ELSEIF LENGTH(p_Etiqueta) >= 9 AND p_Etiqueta REGEXP '^[0-9]+$' THEN
        SELECT IDTags, IDSAE, Identificador, Etiqueta, Activa, CancelacionWA, DocCancelacion, TAGNUEVA, Placa, DocAltaTAG
        FROM Tags
        WHERE Identificador = p_Etiqueta;

    -- Caso por defecto: filtrar solo por p_Etiqueta
    ELSE
        SELECT IDTags, IDSAE, Identificador, Etiqueta, Activa, CancelacionWA, DocCancelacion, TAGNUEVA, Placa, DocAltaTAG
        FROM Tags
        WHERE Etiqueta = p_Etiqueta;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `ObtenerInformacionProcesoCorrecto` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `ObtenerInformacionProcesoCorrecto`()
BEGIN
    SELECT 
        Proceso,
        MensajeExito,
        FechaEjecucion
    FROM 
        ProcesosExitosos;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `ObtenerInformacionProcesoIncorrecto` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `ObtenerInformacionProcesoIncorrecto`()
BEGIN
    SELECT 
        Proceso,
        MensajeError,
        FechaError
    FROM 
        ErroresProcesamiento;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `ObtenerInformacionVigencia` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `ObtenerInformacionVigencia`()
BEGIN

	CALL ActualizarVigenciaAsociado();
    SELECT 
        T.Identificador AS CardNumber,
        1 AS `NIVEL ACCESO`,
        V.Vigencia AS `FECHA EXPIRACION`
    FROM 
        Tags T
    INNER JOIN 
        Vigencia V ON T.IDSAE = V.IDSAE
    WHERE 
        T.Activa = 0;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `ObtenerInformacionVigenciaIncorrecta` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `ObtenerInformacionVigenciaIncorrecta`()
BEGIN
    SELECT 
        VI.IdSAE AS IDSAE,
        A.Nombre AS NOMBREASOCIADO,
        VI.Concepto AS `CONCEPTO`,
        VI.Vigencia AS `VIGENCIA`
    FROM 
        VigenciaIncorrecta VI
    INNER JOIN 
        Asociado A ON VI.IdSAE = A.IDSAE;
        --    VI.Concepto NOT LIKE '%TARJETA DE ACCESO%'
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_ActualizarTagMalUso` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_ActualizarTagMalUso`(
    IN p_Id INT,
    IN p_Etiqueta VARCHAR(50),
    OUT p_Resultado VARCHAR(100)
)
BEGIN
    DECLARE exit handler for sqlexception 
    BEGIN
        -- ✅ Manejo de errores
        ROLLBACK;
        SET p_Resultado = 'Error al actualizar la TAG.';
    END;

    -- ✅ Iniciar una transacción para garantizar consistencia
    START TRANSACTION;

    -- ✅ Actualizar la tabla Tags
    UPDATE Tags
    SET Activa = 0
    WHERE IDSAE = p_Id AND Etiqueta = p_Etiqueta;

    -- ✅ Verificar si realmente se afectó alguna fila
    IF ROW_COUNT() = 0 THEN
        -- Si no hay filas afectadas, retornar mensaje pero **NO lanzar error**
        SET p_Resultado = 'No se encontró la TAG especificada en Tags.';
    ELSE
        -- ✅ Si se actualizó la tabla Tags, actualizar MalUso
        UPDATE MalUso
        SET Estado = 6
        WHERE IDSAE = p_Id AND Tag = p_Etiqueta;

        -- ✅ Verificar si realmente se afectó alguna fila
        IF ROW_COUNT() = 0 THEN
            SET p_Resultado = 'No se encontró el registro en MalUso.';
        ELSE
            -- ✅ Confirmar la transacción si todo está bien
            COMMIT;
            SET p_Resultado = 'TAG actualizada correctamente.';
        END IF;
    END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_GetAsociado` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_GetAsociado`(IN p_IDSAE INT)
BEGIN
    SELECT 
        A.IDAsociado,
        A.IDSAE,
        A.Nombre,
        D.Calle,
        D.NumInt,
        D.NumExt
    FROM 
        Asociado A
    INNER JOIN 
        Direccion D ON A.IDSAE = D.IDSAE
    WHERE 
        A.IDSAE = p_IDSAE;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_GetAsociadosConTag` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_GetAsociadosConTag`()
BEGIN
    SELECT 
        A.IDAsociado,
        A.IDSAE,
        A.Nombre,
        D.Calle,
        D.NumInt,
        D.NumExt,
        T.Etiqueta,
        T.Activa,
        COALESCE(T.CancelacionWA, '') AS CancelacionWA,
        COALESCE(T.DocCancelacion, '') AS DocCancelacion,
        COALESCE(T.Identificador, '') AS Identificador,
        COALESCE(T.DocAltaTag, '') AS DocAltaTag
    FROM 
        Asociado A
    INNER JOIN 
        Direccion D ON A.IDSAE = D.IDSAE
    INNER JOIN 
        Tags T ON A.IDSAE = T.IDSAE
    LIMIT 5000;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_GetAsociadosConTagMalUso` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_GetAsociadosConTagMalUso`()
BEGIN
SELECT 
    A.IDSAE,
    A.Nombre,
    CONCAT(D.Calle, ' ', COALESCE(D.NumInt, ''), ' ', COALESCE(D.NumExt, '')) AS Direccion,
    DA.Telefono,
    DA.CorreoElectronico AS Correo,
    CASE 
        WHEN T.Activa = 0 THEN 'Normal'
        WHEN T.Activa = 2 THEN 'Primera Advertencia'
        WHEN T.Activa = 3 THEN 'Bloqueado'
        WHEN T.Activa = 4 THEN 'Bloqueado Definitivamente'
        ELSE 'Desconocido'
    END AS Estado,
    IFNULL(JSON_ARRAYAGG(
        JSON_OBJECT(
            'nombre', 
                CASE 
                    WHEN T.Etiqueta = 'APP' THEN CONCAT('APP-', T.Identificador)
                    ELSE IFNULL(T.Etiqueta, 'Sin nombre') 
                END,
            'estado', IFNULL(
                CASE 
                    WHEN T.Activa = 0 THEN 'Normal'
                    WHEN T.Activa = 2 THEN 'Primera Advertencia'
                    WHEN T.Activa = 3 THEN 'Bloqueado'
                    WHEN T.Activa = 4 THEN 'Bloqueado Definitivamente'
                    ELSE 'Desconocido'
                END, 'Desconocido'
            ),
            'notificado', IFNULL(T.Notificado, 0),
            'fechaIncidente', IFNULL(LEFT(MU.FechaIncidente, 10), 'NE'),
            'fechaActivacion', IFNULL(LEFT(MU.FechaActivacion, 10), 'NE'),
            'pdfUrl', IFNULL(MU.URLMalUso, 'Documento no Encontrado'),

            -- ✅ Anidación de la Bitácora dentro de cada TAG
            'bitacora', IFNULL((
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'fechaBitacora', IFNULL(LEFT(BMU.FechaBitacora, 20), 'NE'),
                        'comentario', IFNULL(BMU.Comentario, 'Sin descripción')
                    )
                )
                FROM BitacoraMalUso BMU 
                WHERE BMU.IDSAE = A.IDSAE 
                AND BMU.Tag = T.Etiqueta
                AND BMU.Estado IN (2,3,4)
            ), '[]')
        )
    ), '[]') AS Tags
FROM 
    Asociado A
INNER JOIN 
    Direccion D ON A.IDSAE = D.IDSAE
INNER JOIN 
    DatosAdicionales DA ON A.IDSAE = DA.IDSAE
INNER JOIN 
    Tags T ON A.IDSAE = T.IDSAE
LEFT JOIN 
    MalUso MU ON MU.IDSAE = A.IDSAE 
    AND (
        (T.Etiqueta = 'APP' AND TRIM(LOWER(MU.Tag)) = TRIM(LOWER(T.Identificador))) OR
        (T.Etiqueta <> 'APP' AND TRIM(LOWER(MU.Tag)) = TRIM(LOWER(T.Etiqueta)))
    )
    AND MU.Estado IN (2,3,4)
WHERE 
    T.Activa IN (0,2,3,4)
    -- AND T.Etiqueta = '3507-H'
GROUP BY 
    A.IDSAE, A.Nombre, Direccion, DA.Telefono, DA.CorreoElectronico, Estado;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_GetAsociadosConTagV1` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_GetAsociadosConTagV1`()
BEGIN
    SELECT 
        A.IDAsociado,
        A.IDSAE,
        A.Nombre,
        D.Calle,
        D.NumInt,
        D.NumExt,
        T.Etiqueta,
        T.Activa,
        COALESCE(T.CancelacionWA, '') AS CancelacionWA,
        COALESCE(T.DocCancelacion, '') AS DocCancelacion,
        COALESCE(T.Identificador, '') AS Identificador,
        COALESCE(T.DocAltaTag, '') AS DocAltaTag,
        A.Vigencia,
        CASE 
            WHEN STR_TO_DATE(A.Vigencia, '%d/%m/%Y') <= CURDATE() THEN 1
            ELSE 0
        END AS ValidaVigencia
    FROM 
        Asociado A
    INNER JOIN 
        Direccion D ON A.IDSAE = D.IDSAE
    INNER JOIN 
        Tags T ON A.IDSAE = T.IDSAE
    LIMIT 5000;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_GuardarBitacora` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_GuardarBitacora`(
    IN p_Id INT,
	IN p_Tag VARCHAR(100),
    IN p_Estado INT,
    IN p_Comentario VARCHAR(255),
    IN p_Fecha VARCHAR(50)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        ROLLBACK;
        SELECT 0 AS Resultado, 'Error al guardar en la bitácora.' AS Mensaje;
    END;

    START TRANSACTION;

    INSERT INTO BitacoraMalUso (
        IDSAE,
        Tag,
        Comentario,
        FechaBitacora,
        Estado        
    )
    VALUES (
        p_Id,
        p_Tag,
        p_Comentario,
		p_Fecha,
        p_Estado        
    );

    COMMIT;
    SELECT 1 AS Resultado, 'Registro guardado correctamente.' AS Mensaje;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_GuardarNotificacion` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_GuardarNotificacion`(
    IN p_Id INT,
    IN p_Tag VARCHAR(50),
    IN p_ValorNotificado INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 0 AS Resultado, '❌ Error al guardar la notificación.' AS Mensaje;
    END;

    START TRANSACTION;

    UPDATE Tags
    SET Notificado = p_ValorNotificado
    WHERE IDSAE = p_Id AND Etiqueta = p_Tag;

    COMMIT;
    SELECT 1 AS Resultado, 'Notificación guardada correctamente.' AS Mensaje;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_UpdateTag` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `sp_UpdateTag`(
    IN p_IDTags INT,
    IN p_IDSAE INT,
    IN p_Identificador VARCHAR(255),
    IN p_Etiqueta VARCHAR(255),
    IN p_Activa INT,
    IN p_CancelacionWA VARCHAR(255),
    IN p_DocCancelacion VARCHAR(255),
    IN p_TAGNUEVA INT,
    IN p_Placa VARCHAR(255),
    IN p_DocAltaTag VARCHAR(255)
)
BEGIN
    UPDATE Tags
    SET 
        IDSAE = p_IDSAE,
        Identificador = p_Identificador,
        Etiqueta = p_Etiqueta,
        Activa = p_Activa,
        CancelacionWA = p_CancelacionWA,
        DocCancelacion = p_DocCancelacion,
        TAGNUEVA = p_TAGNUEVA,
        Placa = p_Placa,
        DocAltaTag = p_DocAltaTag,
        FechaActualizacion = NOW()
    WHERE IDTags = p_IDTags;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `zsp_Ins_AltaTag` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `zsp_Ins_AltaTag`(
    IN p_IDSAE INT, 
    IN p_Identificador VARCHAR(100),
    IN p_SolicitudAltaTag TEXT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al insertar en AltaTAG';
    END;

    START TRANSACTION;

    INSERT INTO AltaTAG (IDSAE, Identificador, SolicitudAlta, FechaAlta)
    VALUES (p_IDSAE, p_Identificador, p_SolicitudAltaTag, NOW());

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `zsp_Ins_MalUsoTag` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `zsp_Ins_MalUsoTag`(
    IN p_IDSAE INT,
    IN p_Tag VARCHAR(100),
    IN p_URLMalUso VARCHAR(200),
    IN p_FechaIncidente VARCHAR(100),
    IN p_FechaActivacion VARCHAR(100),
    IN p_Estado INT
)
BEGIN
    -- Verificamos el estado para aplicar la lógica correspondiente
    IF p_Estado = 2 THEN
        -- Insertamos el nuevo registro en MalUso
        INSERT INTO MalUso (IDSAE, Tag, URLMalUso, FechaIncidente, FechaActivacion, Estado)
        VALUES (p_IDSAE, p_Tag, p_URLMalUso, p_FechaIncidente, p_FechaActivacion, p_Estado);
        
        -- Actualizamos el campo Activa en la tabla Tags
        UPDATE Tags 
        SET Activa = p_Estado 
        WHERE IDSAE = p_IDSAE 
        AND Etiqueta = p_Tag;

    ELSEIF p_Estado = 3 THEN
        -- Actualizamos a Estado 6 los registros con Estado = 2
        UPDATE MalUso 
        SET Estado = 6 
        WHERE IDSAE = p_IDSAE 
        AND Tag = p_Tag
        AND Estado = 2;
        
        -- Insertamos el nuevo registro en MalUso
        INSERT INTO MalUso (IDSAE, Tag, URLMalUso, FechaIncidente, FechaActivacion, Estado)
        VALUES (p_IDSAE, p_Tag, p_URLMalUso, p_FechaIncidente, p_FechaActivacion, p_Estado);
        
        -- Actualizamos el campo Activa en la tabla Tags
        UPDATE Tags 
        SET Activa = p_Estado 
        WHERE IDSAE = p_IDSAE 
        AND Etiqueta = p_Tag;

    ELSEIF p_Estado = 4 THEN
        -- Actualizamos a Estado 6 los registros con Estado = 3
        UPDATE MalUso 
        SET Estado = 6 
        WHERE IDSAE = p_IDSAE 
        AND Tag = p_Tag
        AND Estado = 3;
        
        -- Insertamos el nuevo registro en MalUso
        INSERT INTO MalUso (IDSAE, Tag, URLMalUso, FechaIncidente, FechaActivacion, Estado)
        VALUES (p_IDSAE, p_Tag, p_URLMalUso, p_FechaIncidente, p_FechaActivacion, p_Estado);
        
        -- Actualizamos el campo Activa en la tabla Tags
        UPDATE Tags 
        SET Activa = p_Estado 
        WHERE IDSAE = p_IDSAE 
        AND Etiqueta = p_Tag;
		END IF;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `zsp_Ins_TagAPPAsociado` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `zsp_Ins_TagAPPAsociado`(
    IN p_IDSAE INT, 
    IN p_Identificador VARCHAR(100),
    IN p_Placa VARCHAR(50),
    IN p_UrlAlta VARCHAR(200)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al insertar en Tags';
    END;

    START TRANSACTION;

    -- Especifica las columnas en el INSERT para mayor claridad y seguridad
    INSERT INTO Tags (IDSAE, Identificador, Etiqueta, Activa, CancelacionWA, DocCancelacion, FechaAlta, FechaActualizacion, TAGNUEVA, Placa, DocAltaTag) 
    VALUES (p_IDSAE, p_Identificador, 'APP', 0, NULL, NULL, NOW(), NULL, 2, p_Placa, p_UrlAlta);

    -- Devolver los valores insertados
    SELECT p_IDSAE AS IDSAE, p_Identificador AS Identificador;

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `zsp_Ins_TagAsociado` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `zsp_Ins_TagAsociado`(
    IN p_IDSAE INT, 
    IN p_Identificador VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al actualizar la tabla Tags';
    END;

    START TRANSACTION;

    UPDATE Tags 
    SET 
        IDSAE = p_IDSAE, 
        FechaAlta = NOW(), 
        TAGNUEVA = 0
    WHERE 
        Etiqueta = p_Identificador;

    COMMIT;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `zsp_Sel_MaxTag` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `zsp_Sel_MaxTag`()
BEGIN
    -- Declaración de variables
    DECLARE UltimaEtiqueta VARCHAR(50);
    DECLARE NumeroEtiqueta INT;
    DECLARE NuevaEtiqueta VARCHAR(50);

    -- Obtener la última etiqueta
    SELECT Etiqueta INTO UltimaEtiqueta
    FROM Tags
    WHERE Etiqueta != 'APP' AND TAGNUEVA = 1
    ORDER BY IDTags ASC
    LIMIT 1;

    -- Extraer la parte numérica, incrementar y formatear nuevamente
    SET NumeroEtiqueta = CAST(SUBSTRING_INDEX(UltimaEtiqueta, '-', 1) AS UNSIGNED);
    SET NuevaEtiqueta = CONCAT(CAST(NumeroEtiqueta AS CHAR), '-', RIGHT(UltimaEtiqueta, 1));

    -- Seleccionar la nueva etiqueta incrementada
    SELECT NuevaEtiqueta AS NuevaEtiqueta;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 DROP PROCEDURE IF EXISTS `zsp_Sel_Users` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_0900_ai_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
CREATE DEFINER=`admin`@`%` PROCEDURE `zsp_Sel_Users`(
    IN p_USER VARCHAR(150),
    IN p_PASSWORD VARCHAR(150)
)
BEGIN
    SELECT  
        U.Id AS IdUser, 
        U.FullName, 
        U.UserName, 
        U.Role_Id AS IdRole, 
        R.Name AS Role, 
        U.Loevm AS Estatus
    FROM    
        USUARIO U
    INNER JOIN 
        ROLE R ON U.Role_Id = R.Id
    WHERE   
        U.UserName = p_USER AND U.Password = p_PASSWORD;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
SET @@SESSION.SQL_LOG_BIN = @MYSQLDUMP_TEMP_LOG_BIN;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-08-12 21:09:57
