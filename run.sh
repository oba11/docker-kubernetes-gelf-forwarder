#!/bin/sh -e

cat << EOF > /fluentd/etc/fluent.conf
<match fluent.**>
  type null
</match>

<source>
  @type tail
  path /var/log/containers/*.log
  pos_file /tmp/fluentd-containers.log.pos
  time_format %Y-%m-%dT%H:%M:%S.%NZ
  tag kubernetes.*
  format json
  read_from_head true
</source>

<filter kubernetes.**>
  @type kubernetes_metadata
</filter>

<filter kubernetes.**>
  @type record_transformer
  enable_ruby
  <record>
    pod_name \${record["kubernetes"]["pod_name"]}
    message \${record["log"]}
    tag kubernetes
    severity \${record["stream"] == 'stderr' ? 'err' : 'info'}
    source \${record["kubernetes"]["host"]}
    hostname \${record["kubernetes"]["pod_name"] || tag_parts[4]}
  </record>
  remove_keys log,stream,docker,kubernetes,labels
</filter>

EOF

for i in $(seq 5)
do
GELFDEPLOYMENT=$(eval echo $(printf "\$GELF_${i}_DEPLOYMENT"))
GELFHOST=$(eval echo $(printf "\$GELF_${i}_HOST"))
GELFPORT=$(eval echo $(printf "\$GELF_${i}_PORT"))
GELFPARSENGINX=$(eval echo $(printf "\$GELF_${i}_PARSE_NGINX"))
if [[ -n "$GELFDEPLOYMENT" ]] && [[ -n "$GELFHOST" ]] && [[ -n "$GELFPORT" ]]; then

if [[ -n "$GELFPARSENGINX" ]]; then
cat << EOF >> /fluentd/etc/fluent.conf
<filter kubernetes.var.log.containers.$GELFDEPLOYMENT**>
  @type parser
  format /^(?<domain>[^ ]*) (?<host>[^ ]*) \[(?<x_forwarded_for>[^\]]*)\] (?<server_port>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?:(?<method>\S+[^\"])(?: +(?<path>[^\"]*?)(?: +(?<protocol>\S*))?)?)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")? (?<request_length>[^ ]*) (?<request_time>[^ ]*) (?:\[(?<proxy_upstream_name>[^\]]*)\] )?(?<upstream_addr>[^ ]*) (?<upstream_response_length>[^ ]*) (?<upstream_response_time>[^ ]*) (?<upstream_status>[^ ]*)$/
  time_format %d/%b/%Y:%H:%M:%S %z
  key_name message
  types server_port:integer,code:integer,size:integer,request_length:integer,request_time:float,upstream_response_length:integer,upstream_response_time:float,upstream_status:integer
  reserve_data yes
  suppress_parse_error_log true
</filter>

EOF
fi

cat << EOF >> /fluentd/etc/fluent.conf
<match kubernetes.var.log.containers.$GELFDEPLOYMENT**>
  @type gelf
  host $GELFHOST
  port $GELFPORT
</match>

EOF
fi
done

exec fluentd -c /fluentd/etc/fluent.conf -p /fluentd/plugins $FLUENTD_OPT
