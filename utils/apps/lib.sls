
{########################################## app_skeleton ######################
  creates app user
  creates skeleton of directories
  uploads deployment ssh key
  registers github ssh fingerprint
#}
{% macro app_skeleton(appslug) %}

{{appslug}}:
  user:
    - present
    - home: /srv/{{appslug}}
    - shell: /bin/bash
    - groups:
      - webservice
      - supervisor
    - require:
      - group: webservice


ssh_github_{{ appslug }}:
  ssh_known_hosts:
    - present
    - name: github.com
    - user: {{ appslug }}
    - fingerprint: {{ salt['pillar.get']('github_ssh_fingerprint', '16:27:ac:a5:76:28:2d:36:63:1b:56:4d:eb:df:a6:48') }}
    - require:
      - user: {{ appslug }}
      - file: /srv/{{ appslug }}/.ssh
    - require_in:
      - git.*


{% for directory in [
  '/var/log/' + appslug,
  '/var/run/' + appslug,
  '/srv/' + appslug,
  '/srv/' + appslug + '/.ssh',
  '/srv/' + appslug + '/application',
  '/srv/' + appslug + '/application/releases',
  '/srv/' + appslug + '/application/shared',
  '/srv/' + appslug + '/application/shared/log',
  '/srv/' + appslug + '/application/shared/pids',
  '/srv/' + appslug + '/application/shared/system',
  '/srv/' + appslug + '/application/shared/tmp',
  '/srv/' + appslug + '/application/shared/session',
] %}


{{directory}}:
  file:
    - directory
    - dir_mode: 751
    - makedirs: True
    - user: {{appslug}}
    - group: {{appslug}}
    - require:
      - user: {{appslug}}


{% endfor %}
#/srv/{{appslug}}/application/current

{% endmacro %}


{########################################## app_install_deploy_key ######################
  install ssh priv key from pillar.deploy.ssh.key_type
#}
{% macro app_install_deploy_key(appslug) %}
private_key_{{ appslug }}:
  file:
    - managed
    - name: /srv/{{ appslug }}/.ssh/{{ pillar.deploy.ssh.key_type }}
    - user: {{ appslug }}
    - group: {{ appslug }}
    - mode: 600
    - contents_pillar: deploy:ssh:privkey
    - require:
      - user: {{ appslug }}
      - file: /srv/{{ appslug }}/.ssh
    - require_in:
      - git.*
{% endmacro %}


{########################################## app_clone ######################
  git clone to application/current
#}
{% macro app_clone(appslug, gitrepo) %}

{{ appslug }}.git:
  git:
    - latest
    - name: {{ gitrepo }}
    - rev: {{ pillar['apps'][appslug]['git_rev']}}
    - user: {{ appslug }}
    - force: True
    - force_checkout: True
    - submodules: True
    - target: /srv/{{appslug}}/application/current

{% endmacro %}


{########################################## app_rails_nginx ######################
  create nginx configuration
#}
{% macro app_rails_nginx(appslug, server_name) %}

/etc/nginx/conf.d/{{appslug}}.conf:
  file:
    - managed
    - source: salt://nginx/templates/vhost-unicorn.conf
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - watch_in:
      - service: nginx
    - require:
      - user: {{appslug}}
    - context:
      appslug: {{appslug}}
      server_name: {{ server_name }}
      unix_socket: ///var/run/{{appslug}}/{{appslug}}.sock:8080
      root_dir: /srv/{{appslug}}/application/current/public
{#    - context:
      proxy_to: {{proxy_to}}
      is_default: {{is_default}}
      client_max_body_size: {{client_max_body_size}}


required:
 - appslug
 - root_dir
 - unix_socket

optional:
 - index_doc
 - server_name

#}


{% endmacro %}
