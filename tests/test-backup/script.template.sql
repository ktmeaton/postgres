\c postgres

\echo 'Pausing scheduled backups'
update timetable.chain set live=false where chain_name like 'backup%';

create database {DB};
\c {DB}

drop table if exists test;
create table test (id integer, name text);
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test-backup" --annotation=comment="after_create"');

\c {DB}
insert into test values (1, 'A');
select pg_sleep(1);
insert into test values (2, 'B');
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test-backup" --annotation=comment="after_insert"');

\c {DB}
delete from test where id = 1 and name = 'A';
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test-backup" --annotation=comment="after_delete"');

\c {DB}
insert into test values (3, 'C');
select pg_sleep(1);
\c postgres
select backup.run('incr', 'source="test-backup" --annotation=comment="after_final"');

\c postgres

\echo 'Resuming scheduled backups'
update timetable.chain set live=true where chain_name like 'backup%';
