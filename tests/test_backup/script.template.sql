\c postgres

create database {DB};
\c {DB}

drop table if exists test;
create table test (id integer, name text);
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test_backup" --annotation=comment="after_create"');

\c {DB}
insert into test values (1, 'A');
select pg_sleep(1);
insert into test values (2, 'B');
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test_backup" --annotation=comment="after_insert"');

\c {DB}
delete from test where id = 1 and name = 'A';
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test_backup" --annotation=comment="after_delete"');

\c {DB}
insert into test values (3, 'C');
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test_backup" --annotation=comment="after_final"');
