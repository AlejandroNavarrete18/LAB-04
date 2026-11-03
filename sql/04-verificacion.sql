-- LAB-04 / 04-verificacion.sql
-- Verificacion final del estado de seguridad (solo lectura)

-- Red
SHOW port;
SHOW listen_addresses;

-- pg_hba.conf: reglas, errores y reglas abiertas
SELECT line_number, type, database, user_name, address, netmask, auth_method, error
FROM pg_hba_file_rules ORDER BY line_number;

SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules
WHERE netmask IN ('0.0.0.0', '::');

-- Autenticacion
SHOW password_encryption;

-- Roles y privilegios
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles ORDER BY rolname;

-- Extensiones
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Parametros de conexion
SHOW max_connections;
SHOW superuser_reserved_connections;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;
SHOW log_connections;
SHOW log_disconnections;

-- TLS
SHOW ssl;
SHOW ssl_min_protocol_version;
SELECT s.pid, a.usename, a.client_addr, s.ssl, s.version, s.cipher
FROM pg_stat_ssl s
JOIN pg_stat_activity a USING (pid)
WHERE s.pid = pg_backend_pid();

-- Conexiones activas
SELECT pid, usename, datname, client_addr, application_name
FROM pg_stat_activity WHERE datname IS NOT NULL;