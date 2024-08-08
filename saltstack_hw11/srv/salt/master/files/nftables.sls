---
nftables:
  pkg.installed:
    - name: nftables
  service.running:
    - watch:
      - file: /etc/sysconfig/nftables.conf
    - enable: true
    - requre:
      - pkg: nftables
/etc/sysconfig/nftables.conf:
  file.managed:
    - source: salt://master/files/nftables/nftables.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 0600
...