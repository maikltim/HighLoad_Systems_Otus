---
sshd:
  service.dead:
    - enable: false
include:
 - .nftables
 - .selinux
 - .php-fpm
 - .nginx
 - .wordpress
...