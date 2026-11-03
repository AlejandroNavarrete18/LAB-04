-- LAB-04 / 03-configuracion.sql


-- Actividad 7: autenticacion 
SHOW password_encryption;

--   Actividad 10: extensiones  
SELECT extname, extversion FROM pg_extension ORDER BY extname;

--  Actividad 11: parametros de conexion  
SHOW max_connections;
SHOW superuser_reserved_connections;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;

-- Funcion de cada parametro (para documentarla)
SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN ('max_connections', 'superuser_reserved_connections',
               'statement_timeout', 'idle_in_transaction_session_timeout');

--   Actividad 15: TLS  
SHOW ssl;
SHOW ssl_min_protocol_version;

-- pg_stat_ssl no tiene usename ni client_addr: se obtienen de pg_stat_activity
SELECT s.pid, a.usename, a.client_addr, s.ssl, s.version, s.cipher
FROM pg_stat_ssl s
JOIN pg_stat_activity a USING (pid)
WHERE s.pid = pg_backend_pid();