selinux:
  state: enforcing
  type: targeted
  booleans.enabled:
    - httpd_can_network_connect
  booleans.disabled:
    - httpd_can_network_connect_db
  ports:
    ssh:
      tcp:
        - 22
  ports.absent:
    ssh:
      tcp:
        - 2222
  fcontext:
    /var/www/test.org/statics(/.*)?:
      user: system_u
      type: httpd_sys_rw_content_t
  fcontext.absent:
    - /var/www/test.org/src(/.*)?
    - /var/www/test.org/tests