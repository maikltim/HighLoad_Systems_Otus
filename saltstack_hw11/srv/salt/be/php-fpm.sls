---
php-packages:
  pkg.installed:
    - pkgs:
      - php-fpm
      - php-mysqlnd
      - php-bcmath
      - php-mbstring
      - php-pdo
      - php-xml
  service.running:
    - name: php-fpm
    - enable: true
    - require:
      - pkg: php-packages
...