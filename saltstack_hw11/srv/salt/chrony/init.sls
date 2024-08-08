---
chrony:
  pkg.installed

chronyd:
  service.running:
    - enable: true
    - require:
      - pkg: chrony

Europe/Moscow:
  timezone.system
...