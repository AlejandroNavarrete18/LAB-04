-- LAB-04 / 01-inspeccion.sql  (solo lectura)
-- Act. 1 - Superficie de ataque
SELECT version();
SHOW port;
SHOW listen_addresses;
SHOW ssl;
SHOW password_encryption;

SELECT pid, usename, datname, client_addr, client_port, application_name
FROM pg_stat_activity;

-- Act. 2 - Archivos de configuracion (datos / configuracion / autenticacion / logs)
SHOW config_file;
SHOW hba_file;
SHOW ident_file;
SHOW data_directory;
SHOW log_directory;
SHOW log_connections;
SHOW log_disconnections;

-- Act. 3 - listen_addresses y su origen (para saber en que archivo se definio)
SHOW listen_addresses;
SELECT name, setting, source, sourcefile, pending_restart
FROM pg_settings WHERE name IN ('listen_addresses','port');

-- Act. 4 - Reglas de pg_hba.conf
SELECT type, database, user_name, address, auth_method FROM pg_hba_file_rules;

-- Reglas excesivamente amplias (0.0.0.0/0 y ::/0)
SELECT line_number, type, database, user_name, address, netmask, auth_method
FROM pg_hba_file_rules
WHERE netmask IN ('0.0.0.0','::');

-- Act. 10 - Extensiones
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Act. 11 - Parametros de conexion
SHOW max_connections;
SHOW superuser_reserved_connections;
SHOW statement_timeout;
SHOW idle_in_transaction_session_timeout;

-- Act. 15 - TLS
SHOW ssl;
SHOW ssl_min_protocol_version;
SELECT pid, usename, client_addr, ssl, version, cipher
FROM pg_stat_ssl WHERE pid = pg_backend_pid();
