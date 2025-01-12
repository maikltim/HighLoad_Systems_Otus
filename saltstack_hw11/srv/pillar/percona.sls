# Define root password for percona server
mysql_root_user: root
mysql_root_password: root@Otus1234

# Some defaults variables for percona server config file
#mysql_port: 3306
bind_address: 0.0.0.0
max_allowed_packet: 16M
key_buffer: 16M
thread_stack: 192K
thread_cache_size: 8

# Uncomment following vars if you want to log queries
sqldebug: true
log_slow_queries: log_slow_queries    = /var/log/mysql/mysql-slow.log
slow_query_log: slow_query_log       = 1
log_output: log_output           = TABLE
long_query_time: long_query_time      = 2
log_queries_not_using_indexes: log-queries-not-using-indexes