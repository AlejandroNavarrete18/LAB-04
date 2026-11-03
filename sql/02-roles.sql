-- LAB-04 / 02-roles.sql
-- Act. 8 - Revision de roles
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin
FROM pg_roles WHERE rolname !~ '^pg_' ORDER BY rolname;

-- Act. 9 - Separacion de cuentas: DBA / APP / CONSULTA
-- Ejecutar como administrador del laboratorio. Base y nombres: ajustar al entorno.
CREATE DATABASE basedatos_app;


CREATE ROLE dba_admin     LOGIN NOSUPERUSER CREATEROLE CREATEDB;   -- administracion, sin superusuario
CREATE ROLE app_user      LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB CONNECTION LIMIT 20;
CREATE ROLE consulta_user LOGIN NOSUPERUSER NOCREATEROLE NOCREATEDB CONNECTION LIMIT 5;
-- Asignar contrasenas sin escribirlas en el script (se almacenan con SCRAM):
-- \password dba_admin
-- \password app_user
-- \password consulta_user

REVOKE ALL ON DATABASE basedatos_app FROM PUBLIC;
GRANT CONNECT ON DATABASE basedatos_app TO app_user, consulta_user, dba_admin;
GRANT USAGE ON SCHEMA public TO app_user, consulta_user;

-- app_user: solo lo que necesita la aplicacion (sin DELETE ni DDL)
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_user;
-- consulta_user: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA public TO consulta_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO consulta_user;

-- Verificacion
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit
FROM pg_roles WHERE rolname IN ('dba_admin','app_user','consulta_user');
