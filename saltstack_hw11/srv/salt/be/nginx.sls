---
nginx:
  pkg.installed:
    - name: nginx
  service.running:
    - watch:
        - file: /etc/nginx/nginx.conf
    - enable: true
    - require:
      - pkg: nginx
  file.managed:
    - name: /etc/nginx/nginx.conf
    - source: salt://be/files/nginx/nginx.conf.jinja
    - template: jinja
...