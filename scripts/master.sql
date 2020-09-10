--
-- change recovery model and take full backup for db to meet requirements of AOAG
--

ALTER DATABASE [Sales] SET RECOVERY FULL
GO

BACKUP DATABASE [Sales]
TO
  DISK = N'/var/opt/mssql/backup/Sales.bak'
WITH
  NOFORMAT,
  NOINIT,
  NAME = N'Sales-Full Database Backup',
  SKIP,
  NOREWIND,
  NOUNLOAD,
  STATS = 10
GO

USE [master]
GO

-- create logins for aoag

-- this password could also be originate from an environemnt variable
-- passed in to this script through SQLCMD

CREATE LOGIN aoag_login WITH PASSWORD = 'Pa$$w0rd'
CREATE USER aoag_user FOR LOGIN aoag_login
GO

-- create certificate for AOAG

-- this password could also be originate from an environemnt variable
-- passed in to this script through SQLCMD

CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
GO

CREATE CERTIFICATE aoag_certificate WITH SUBJECT = 'aoag_certificate'

BACKUP CERTIFICATE aoag_certificate
TO FILE = '/var/opt/mssql/shared/aoag_certificate.cert'
WITH PRIVATE KEY (
        FILE = '/var/opt/mssql/shared/aoag_certificate.key',
        ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
    )
GO

-- create HADR endpoint on port 5022
CREATE ENDPOINT [Hadr_endpoint]
STATE=STARTED
AS TCP (
    LISTENER_PORT = 5022,
    LISTENER_IP = ALL
)
FOR DATA_MIRRORING (
    ROLE = ALL,
    AUTHENTICATION = CERTIFICATE aoag_certificate,
    ENCRYPTION = DISABLED
--    ENCRYPTION = REQUIRED ALGORITHM AES
)

GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO [aoag_login];
GO

---------------------------------------------------------------------------------------------
--CREATE PRIMARY AG GROUP ON PRIMARY CLUSTER PRIMARY REPLICA
---------------------------------------------------------------------------------------------
--for clusterless AOAG the failover mode always needs to be manual

CREATE AVAILABILITY GROUP [AG1]
WITH (CLUSTER_TYPE = NONE)
FOR REPLICA ON
N'$(HOSTNAME)' WITH
(
    ENDPOINT_URL = N'tcp://$(HOSTNAME):5022',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    SEEDING_MODE = AUTOMATIC,
    FAILOVER_MODE = MANUAL,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
),
N'replica' WITH
(
    ENDPOINT_URL = N'tcp://replica:5022',
    AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
    SEEDING_MODE = AUTOMATIC,
    FAILOVER_MODE = MANUAL,
    SECONDARY_ROLE (ALLOW_CONNECTIONS = ALL)
)

--wait a bit and add database to AG
USE [master]
GO

WAITFOR DELAY '00:00:10'
ALTER AVAILABILITY GROUP [AG1] ADD DATABASE [Sales]
GO
