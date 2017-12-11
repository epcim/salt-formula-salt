{%- from "salt/map.jinja" import minion with context %}
{%- if minion.enabled %}

{%- if minion.source.get('engine', 'pkg') == 'pkg' %}

salt_minion_packages:
  pkg.installed:
  - names: {{ minion.pkgs }}
  {%- if minion.source.version is defined %}
  - version: {{ minion.source.version }}
  {%- endif %}

salt_minion_dependency_packages:
  pkg.installed:
  - pkgs: {{ minion.dependency_pkgs }}

{%- elif minion.source.get('engine', 'pkg') == 'pip' %}

salt_minion_packages:
  pip.installed:
  - name: salt{% if minion.source.version is defined %}=={{ minion.source.version }}{% endif %}

salt_minion_dependency_packages:
  pkg.installed:
  - pkgs: {{ minion.dependency_pkgs_pip }}

{%- endif %}

/etc/salt/minion.d/minion.conf:
  file.managed:
  - source: salt://salt/files/minion.conf
  - user: root
  - group: root
  - template: jinja
  - require:
    - {{ minion.install_state }}

{#- Salt minion module additional configuration. Salt supports hundreds of modules, this formula pillar systematically structured #}
{#- provides support for most frequently used modules. In order to provide additional support to configure whatever configuration #}
{#- in ``minion.conf`` for any module without a need of dedicated formula dependency specify `salt:minion:config` pillar.         #}

{#- If you intend add minion configuration for any existing salt-formula please use <formula repo>/<formula>/meta/salt.yml        #}

{#- This pillar is expected be used while ``masterless``, ``salt --local``, to configure modules without support in salt-formula. #}
{#- in salt state calls. It's not documented in README.rst as we recognize it a bad pattern for salt-formulas ecosystem. Example: #}
{#-  salt:                      #}
{#-    minion:                  #}
{#-      config:                #}
{#-        influxdb:            #}
{#-          host: localhost    #}
{#-          port: 8086         #}
{#-        mysqlite:            #}
{#-          driver: sqlite3    #}
{%- if minion.config is mapping %}
salt_minion_config_present:
  file.serialize:
  - name:            /etc/salt/minion.d/minion.conf
  - dataset_pillar:  salt:minion:config
  - formatter:       yaml
  - merge_if_exists: True
  - makedirs: True
  - require:
    - {{ minion.install_state }}
  - require_in:
    - service: {{ minion.service }}
{%- endif %}


{%- for service_name, service in pillar.items() %}
    {%- set support_fragment_file = service_name+'/meta/salt.yml' %}
    {%- macro load_support_file() %}{% include support_fragment_file ignore missing %}{% endmacro %}
    {%- set support_yaml = load_support_file()|load_yaml %}

    {%- if support_yaml and support_yaml.get('minion', {}) %}
      {%- for name, conf in support_yaml.get('minion', {}).iteritems() %}
salt_minion_config_{{ service_name }}_{{ name }}:
  file.managed:
    - name: /etc/salt/minion.d/_{{ name }}.conf
    - contents: |
        {{ conf|yaml(False)|indent(8) }}
    - require:
      - {{ minion.install_state }}

salt_minion_config_{{ service_name }}_{{ name }}_validity_check:
  cmd.run:
    - name: python -c "import yaml; stream = file('/etc/salt/minion.d/_{{ name }}.conf', 'r'); yaml.load(stream); stream.close()"
    - onchanges:
      - file: salt_minion_config_{{ service_name }}_{{ name }}
    - onchanges_in:
      - cmd: salt_minion_service_restart
      {%- endfor %}
    {%- endif %}
{%- endfor %}

salt_minion_service:
  service.running:
    - name: {{ minion.service }}
    - enable: true
    - require:
      - pkg: salt_minion_packages
      - pkg: salt_minion_dependency_packages
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}

{#- Restart salt-minion if needed but after all states are executed #}
salt_minion_service_restart:
  cmd.run:
    - name: 'while true; do salt-call saltutil.running|grep fun: && continue; salt-call --local service.restart {{ minion.service }}; break; done'
    - shell: /bin/bash
    - bg: true
    - order: last
    - onchanges:
      - file: /etc/salt/minion.d/minion.conf
    {%- if grains.get('noservices') %}
    - onlyif: /bin/false
    {%- endif %}
    - require:
      - service: salt_minion_service

salt_minion_sync_all:
  module.run:
    - name: 'saltutil.sync_all'
    - onchanges:
      - service: salt_minion_service
    - require:
      - pkg: salt_minion_packages
      - pkg: salt_minion_dependency_packages

{%- endif %}
