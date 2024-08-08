---
sshd:
  service.dead:
    - enable: false
include:
 - .nftables
 - .selinux
 - .nginx
...