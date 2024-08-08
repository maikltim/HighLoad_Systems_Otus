---
{% set mysql_root_user = pillar['mysql_root_user'] %}
{% set mysql_root_password = pillar['mysql_root_password'] %}
{% set wp_db_name = pillar['wp_db_name'] %}
{% set wp_db_user = pillar['wp_db_user'] %}
{% set wp_db_pass = pillar['wp_db_pass'] %}

percona-key:
  cmd.run:
    - name: rpm --import https://www.percona.com/downloads/RPM-GPG-KEY-percona

percona-release:
  pkg.installed:
    - sources:
      - percona-release: https://repo.percona.com/yum/percona-release-latest.noarch.rpm

setup_ps80:
  cmd.run:
    - name: echo 'y' | percona-release setup ps80
    - require:
      - pkg: percona-release

#install_packages:
#  pkg.installed:
#    pkgs:
#      - percona-server-server
#      - python3-PyMySQL

percona-server-server:
  pkg.installed

python3-PyMySQL:
  pkg.installed

mysql:
  service.running:
    - watch:
      - file: '/etc/my.cnf.d/my.cnf'
    - enable: true
    - require:
      - pkg: percona-server-server

/etc/my.cnf.d/my.cnf:
  file.managed:
    - source: salt://db/files/percona/my.cnf.jinja
    - template: jinja

change_root_password:
  cmd.run:
    - name: |
        temp_root_pass=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -n 1)
        /usr/bin/mysql -u{{ mysql_root_user }} -p$temp_root_pass --connect-expired-password -e "ALTER USER '{{ mysql_root_user }}'@'localhost' IDENTIFIED WITH caching_sha2_password BY '{{ mysql_root_password }}';"
    - require:
      - service: mysql

create_fnv1a_64_fnv_64_murmur_hash:
  cmd.run:
    - name: |
        /usr/bin/mysql -u{{ mysql_root_user }} -p{{ mysql_root_password }} -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
        /usr/bin/mysql -u{{ mysql_root_user }} -p{{ mysql_root_password }} -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
        /usr/bin/mysql -u{{ mysql_root_user }} -p{{ mysql_root_password }} -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"

create_mysql_database:
  cmd.run:
    - name: /usr/bin/mysql -u{{ mysql_root_user }} -p{{ mysql_root_password }} -e "CREATE DATABASE {{ wp_db_name }}"
    - require:
      - service: mysql

create_mysql_user:
  cmd.run:
    - name: |
        /usr/bin/mysql -u{{ mysql_root_user }} -p{{ mysql_root_password }} -e "CREATE USER '{{ wp_db_user }}'@'10.10.10.%' IDENTIFIED WITH caching_sha2_password BY '{{ wp_db_pass }}';"
        /usr/bin/mysql -u{{ mysql_root_user }} -p{{ mysql_root_password }} -e "GRANT ALL PRIVILEGES ON *.* TO '{{ wp_db_user }}'@'10.10.10.%';"
    - require:
      - service: mysql
...