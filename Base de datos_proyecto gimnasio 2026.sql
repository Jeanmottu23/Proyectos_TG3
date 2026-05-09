/*========================================================
 CREACION DE BASE DE DATOS
========================================================*/

CREATE DATABASE GimnasioDB;
GO

USE GimnasioDB;
GO

/*========================================================
 TABLAS
========================================================*/

-- TABLA SOCIOS
CREATE TABLE Socios(
    IdSocio INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Documento NVARCHAR(20) NOT NULL UNIQUE,
    Email NVARCHAR(100),
    Telefono NVARCHAR(20),
    FechaNacimiento DATE NOT NULL,
    FechaAlta DATETIME2 DEFAULT GETDATE(),
    Activo BIT DEFAULT 1
);
GO

-- TABLA MEMBRESIAS
CREATE TABLE Membresias(
    IdMembresia INT PRIMARY KEY IDENTITY(1,1),
    Tipo NVARCHAR(50) NOT NULL,
    Precio DECIMAL(10,2) NOT NULL,
    CantidadClases INT NULL,
    
    CONSTRAINT CHK_Precio CHECK (Precio > 0)
);
GO

-- TABLA INSTRUCTORES
CREATE TABLE Instructores(
    IdInstructor INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Especialidad NVARCHAR(100),
    Email NVARCHAR(100),
    Telefono NVARCHAR(20),
    Activo BIT DEFAULT 1
);
GO

-- TABLA CLASES
CREATE TABLE Clases(
    IdClase INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Tipo NVARCHAR(50) NOT NULL,
    IdInstructor INT NOT NULL,
    DiasHorario NVARCHAR(100),
    CupoMaximo INT NOT NULL,

    CONSTRAINT FK_Clase_Instructor
        FOREIGN KEY (IdInstructor)
        REFERENCES Instructores(IdInstructor),

    CONSTRAINT CHK_Cupo CHECK (CupoMaximo > 0)
);
GO

-- TABLA INSCRIPCIONES
CREATE TABLE Inscripciones(
    IdInscripcion INT PRIMARY KEY IDENTITY(1,1),
    IdSocio INT NOT NULL,
    IdMembresia INT NOT NULL,
    FechaInicio DATE NOT NULL,
    FechaVencimiento DATE NOT NULL,
    Estado NVARCHAR(20) DEFAULT 'activa',

    CONSTRAINT FK_Inscripcion_Socio
        FOREIGN KEY (IdSocio)
        REFERENCES Socios(IdSocio),

    CONSTRAINT FK_Inscripcion_Membresia
        FOREIGN KEY (IdMembresia)
        REFERENCES Membresias(IdMembresia),

    CONSTRAINT CHK_Estado
        CHECK (Estado IN ('activa','vencida','cancelada'))
);
GO

-- TABLA ASISTENCIAS
CREATE TABLE Asistencias(
    IdAsistencia INT PRIMARY KEY IDENTITY(1,1),
    IdSocio INT NOT NULL,
    IdClase INT NOT NULL,
    FechaHoraEntrada DATETIME2 NOT NULL,
    FechaHoraSalida DATETIME2 NULL,

    CONSTRAINT FK_Asistencia_Socio
        FOREIGN KEY (IdSocio)
        REFERENCES Socios(IdSocio),

    CONSTRAINT FK_Asistencia_Clase
        FOREIGN KEY (IdClase)
        REFERENCES Clases(IdClase)
);
GO

-- TABLA PAGOS
CREATE TABLE Pagos(
    IdPago INT PRIMARY KEY IDENTITY(1,1),
    IdInscripcion INT NOT NULL,
    Monto DECIMAL(10,2) NOT NULL,
    FechaPago DATETIME2 DEFAULT GETDATE(),
    MedioPago NVARCHAR(30) NOT NULL,

    CONSTRAINT FK_Pago_Inscripcion
        FOREIGN KEY (IdInscripcion)
        REFERENCES Inscripciones(IdInscripcion),

    CONSTRAINT CHK_MedioPago
        CHECK (MedioPago IN ('efectivo','transferencia','tarjeta'))
);
GO

-- TABLA AUDITORIA
CREATE TABLE Auditoria(
    IdAuditoria INT PRIMARY KEY IDENTITY(1,1),
    Tabla NVARCHAR(50),
    Accion NVARCHAR(50),
    UsuarioSistema NVARCHAR(100),
    Fecha DATETIME2 DEFAULT GETDATE(),
    Descripcion NVARCHAR(500)
);
GO

/*========================================================
 DATOS DE PRUEBA
========================================================*/

INSERT INTO Socios
(Nombre, Documento, Email, Telefono, FechaNacimiento)
VALUES
('Juan Perez','45678901','juan@gmail.com','099111111','1995-05-10'),
('Maria Garcia','47888999','maria@gmail.com','099222222','1998-08-15'),
('Carlos Lopez','49999888','carlos@gmail.com','099333333','1990-12-01');
GO

INSERT INTO Membresias
(Tipo, Precio, CantidadClases)
VALUES
('Mensual',2500,NULL),
('Trimestral',6500,NULL),
('Anual',24000,NULL),
('Clase suelta',500,1);
GO

INSERT INTO Instructores
(Nombre, Especialidad, Email, Telefono)
VALUES
('Lucia Fernandez','Yoga','lucia@gmail.com','098111111'),
('Martin Silva','Crossfit','martin@gmail.com','098222222');
GO

INSERT INTO Clases
(Nombre, Tipo, IdInstructor, DiasHorario, CupoMaximo)
VALUES
('Yoga Inicial','Yoga',1,'Lunes y Miercoles 19:00',20),
('Crossfit Pro','Crossfit',2,'Martes y Jueves 20:00',15);
GO

/*========================================================
 STORED PROCEDURE
========================================================*/

CREATE PROCEDURE sp_inscribir_socio
    @IdSocio INT,
    @IdMembresia INT,
    @FechaInicio DATE,
    @FechaVencimiento DATE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        IF EXISTS(
            SELECT 1
            FROM Inscripciones
            WHERE IdSocio = @IdSocio
            AND Estado = 'activa'
            AND FechaVencimiento >= GETDATE()
        )
        BEGIN
            RAISERROR('El socio ya tiene una inscripcion activa.',16,1);
            RETURN;
        END

        INSERT INTO Inscripciones
        (IdSocio, IdMembresia, FechaInicio, FechaVencimiento, Estado)
        VALUES
        (@IdSocio, @IdMembresia, @FechaInicio, @FechaVencimiento, 'activa');

        PRINT 'Inscripcion realizada correctamente';

    END TRY

    BEGIN CATCH

        PRINT ERROR_MESSAGE();

    END CATCH
END;
GO

/*========================================================
 EJECUCION DEL SP
========================================================*/

EXEC sp_inscribir_socio
    1,
    1,
    '2026-05-01',
    '2026-06-01';
GO

/*========================================================
 TRIGGER DE AUDITORIA
========================================================*/

CREATE TRIGGER trg_auditoria_inscripciones
ON Inscripciones
AFTER UPDATE
AS
BEGIN

    INSERT INTO Auditoria
    (Tabla, Accion, UsuarioSistema, Fecha, Descripcion)
    SELECT
        'Inscripciones',
        'UPDATE',
        SYSTEM_USER,
        GETDATE(),
        'Se modifico o cancelo una inscripcion ID: '
        + CAST(i.IdInscripcion AS NVARCHAR)
    FROM inserted i;

END;
GO

/*========================================================
 TRIGGER VALIDACION ASISTENCIA
========================================================*/

CREATE TRIGGER trg_validar_asistencia
ON Asistencias
INSTEAD OF INSERT
AS
BEGIN

    IF EXISTS(
        SELECT 1
        FROM inserted i
        WHERE NOT EXISTS(
            SELECT 1
            FROM Inscripciones ins
            WHERE ins.IdSocio = i.IdSocio
            AND ins.Estado = 'activa'
            AND ins.FechaVencimiento >= GETDATE()
        )
    )
    BEGIN
        RAISERROR(
        'El socio no tiene una membresia activa y vigente.',
        16,
        1
        );

        RETURN;
    END

    INSERT INTO Asistencias
    (IdSocio, IdClase, FechaHoraEntrada, FechaHoraSalida)
    SELECT
        IdSocio,
        IdClase,
        FechaHoraEntrada,
        FechaHoraSalida
    FROM inserted;

END;
GO

/*========================================================
 TRIGGER ADICIONAL
 CONTROL DE CUPO EN CLASES
========================================================*/

CREATE TRIGGER trg_control_cupo
ON Asistencias
AFTER INSERT
AS
BEGIN

    IF EXISTS(
        SELECT 1
        FROM Clases c
        INNER JOIN inserted i
            ON c.IdClase = i.IdClase
        WHERE (
            SELECT COUNT(*)
            FROM Asistencias a
            WHERE a.IdClase = c.IdClase
            AND CAST(a.FechaHoraEntrada AS DATE)
                = CAST(i.FechaHoraEntrada AS DATE)
        ) > c.CupoMaximo
    )
    BEGIN
        RAISERROR(
        'Se supero el cupo maximo permitido para la clase.',
        16,
        1
        );

        ROLLBACK TRANSACTION;
    END

END;
GO

/*========================================================
 PRUEBAS
========================================================*/

-- ASISTENCIA VALIDA
INSERT INTO Asistencias
(IdSocio, IdClase, FechaHoraEntrada)
VALUES
(1,1,GETDATE());
GO

-- PAGO
INSERT INTO Pagos
(IdInscripcion, Monto, MedioPago)
VALUES
(1,2500,'tarjeta');
GO

/*========================================================
 CONSULTAS
========================================================*/

SELECT * FROM Socios;
SELECT * FROM Membresias;
SELECT * FROM Inscripciones;
SELECT * FROM Asistencias;
SELECT * FROM Pagos;
SELECT * FROM Auditoria;
GO