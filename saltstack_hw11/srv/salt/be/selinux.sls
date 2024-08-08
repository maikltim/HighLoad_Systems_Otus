---

{% set selinux  = pillar.get('selinux', {}) -%}

{% if grains['os_family'] == 'RedHat' %}
selinux:
  pkg.installed:
    - pkgs:
{% if ( grains['saltversion'] >= '2017.7.0' and grains['osmajorrelease'] <= 7 ) or ( grains['saltversion'] < '2017.7.0' and grains['osmajorrelease'][0]|int <= 7 ) %}
      - policycoreutils-python
{% else %}
      - policycoreutils-python-utils
{% endif %}
{% if ( grains['saltversion'] >= '2017.7.0' and grains['osmajorrelease'] == 7 ) or ( grains['saltversion'] < '2017.7.0' and grains['osmajorrelease'][0] == '7' ) %}
      - policycoreutils-devel
{%- endif %}

/etc/selinux/src:
  file.directory:
    - user: root
    - group: root

{% for bool in salt['pillar.get']('selinux:booleans.enabled', {}) %}
selinux_boolean_{{ bool }}_enabled:
  selinux.boolean:
    - name: {{ bool }}
    - value: 'on'
    - persist: True
{% endfor %}

{% for bool in salt['pillar.get']('selinux:booleans.disabled', {}) %}
selinux_boolean_{{ bool }}_disabled:
  selinux.boolean:
    - name: {{ bool }}
    - value: 'off'
    - persist: True
{% endfor %}

{% for application, config in salt['pillar.get']('selinux:ports', {}).items() %}
{% for protocol, ports in config.items() %}
{% for port in ports %}
selinux_{{ application }}_{{ protocol }}_port_{{ port }}:
  cmd:
    - run
    - name: /usr/sbin/semanage port -a -t {{ application }}_port_t -p {{ protocol }} {{ port }}
    - require:
      - pkg: selinux
    - unless: FOUND="no"; for i in $(/usr/sbin/semanage port -l | grep {{ application }}_port_t | tr -s ' ' | cut -d ' ' -f 3- | tr -d ','); do if [ "$i" == "{{ port }}" ]; then FOUND="yes"; fi; done; if [ "$FOUND" == "yes" ]; then /bin/true; else /bin/false; fi
{% endfor %}
{% endfor %}
{% endfor %}

{% for application, config in salt['pillar.get']('selinux:ports.absent', {}).items() %}
{% for protocol, ports in config.items() %}
{% for port in ports %}
selinux_{{ application }}_{{ protocol }}_port_{{ port }}_absent:
  cmd:
    - run
    - name: /usr/sbin/semanage port -d -t {{ application }}_port_t -p {{ protocol }} {{ port }}
    - require:
      - pkg: selinux
    - unless: FOUND="no"; for i in $(/usr/sbin/semanage port -l | grep {{ application }}_port_t | tr -s ' ' | cut -d ' ' -f 3- | tr -d ','); do if [ "$i" == "{{ port }}" ]; then FOUND="yes"; fi; done; if [ "$FOUND" == "yes" ]; then /bin/false; else /bin/true; fi
{% endfor %}
{% endfor %}
{% endfor %}

{% for file, config in salt['pillar.get']('selinux:fcontext', {}).items() %}
{% set parameters = [] %}
{% if 'type' in config %}
  {% do parameters.append('-t ' + config.type) %}
{% endif %}
{% if 'user' in config %}
  {% do parameters.append('-s ' + config.user) %}
{% endif %}
selinux_fcontext_{{ file }}:
  cmd:
    - run
    - name: if (/usr/sbin/semanage fcontext --list | grep "^{{ file }}"); then /usr/sbin/semanage fcontext -m {{ ' '.join(parameters) }} "{{ file }}"; else /usr/sbin/semanage fcontext -a {{ ' '.join(parameters) }} "{{ file }}" ; fi
    - unless: (/usr/sbin/semanage fcontext --list | grep "^{{ file }}"|grep -E "{{ config.user }}:(.*)?{{ config.type }}")
    - require:
      - pkg: selinux
{% endfor %}

{% for file in salt['pillar.get']('selinux:fcontext.absent', {}) %}
selinux_fcontext_{{ file }}_absent:
  cmd:
    - run
    - name: /usr/sbin/semanage fcontext -d "{{ file }}"
    - require:
      - pkg: selinux
    - unless: if (/usr/sbin/semanage fcontext --list | grep -q "^{{ file }} "); then /bin/false; else /bin/true; fi
{% endfor %}

{% endif %}
...