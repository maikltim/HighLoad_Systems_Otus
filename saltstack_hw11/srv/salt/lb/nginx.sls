---
nginx:
  pkg.installed:
    - name: nginx
  service.running:
    - watch:
      - file: /etc/nginx/nginx.conf
      - file: /etc/nginx/conf.d/upstream.conf
    - enable: true
    - requre:
      - pkg: nginx
/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://lb/files/nginx/nginx.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 640
/etc/nginx/conf.d/upstream.conf:
  file.managed:
    - source: salt://lb/files/nginx/upstream.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 640
...