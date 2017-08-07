#!/bin/sh -e

mkdir -p /tmp/fluentd

cat << EOF > /fluentd/etc/fluent.conf
<match fluent.**>
  @type null
</match>

<source>
  @type tail
  path /var/log/containers/*.log
  pos_file /tmp/fluentd/containers.log.pos
  time_format %Y-%m-%dT%H:%M:%S.%NZ
  tag kubernetes.*
  format json
  read_from_head true
</source>

<source>
  @type systemd
  tag kube-service
  path ${JOURNAL_PATH:=/var/log/journal}
  filters [{ "_SYSTEMD_UNIT": "kube-apiserver.service" },{ "_SYSTEMD_UNIT": "kube-controller-manager.service" },{ "_SYSTEMD_UNIT": "kube-scheduler.service" },{ "_SYSTEMD_UNIT": "kubelet.service" },{ "_SYSTEMD_UNIT": "kube-proxy.service" },{ "_SYSTEMD_UNIT": "localkube.service" }]
  read_from_head true
  <storage>
    @type local
    persistent true
    path /tmp/fluentd/kube-service.pos
  </storage>
  <entry>
    field_map {"MESSAGE": "message", "_PID": ["process", "pid"], "_CMDLINE": "process", "_COMM": "cmd"}
    fields_strip_underscores true
    fields_lowercase true
  </entry>
</source>

<match kube-service>
  @type gelf
  host $GELF_1_HOST
  port $GELF_1_PORT
  flush_interval 3s
</match>

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
    hostname \${record["kubernetes"]["host"] || tag_parts[4]}
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
if [ -n "$GELFDEPLOYMENT" ] && [ -n "$GELFHOST" ] && [ -n "$GELFPORT" ]; then

if [ -n "$GELFPARSENGINX" ]; then
cat << EOF >> /fluentd/etc/fluent.conf
<filter kubernetes.var.log.containers.$GELFDEPLOYMENT**>
  @type parser
  format /^(?<domain>[^ ]*) (?<remote_addr>[^ ]*) \[(?<x_forwarded_for>[^\]]*)\] (?<server_port>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?:(?<method>\S+[^\"])(?: +(?<path>[^\"]*?)(?: +(?<protocol>\S*))?)?)?" (?<status>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<user_agent>[^\"]*)")? (?<request_length>[^ ]*) (?<request_time>[^ ]*) (?:\[(?<proxy_upstream_name>[^\]]*)\] )?(?<upstream_addr>[^ ]*) (?<upstream_response_length>[^ ]*) (?<upstream_response_time>[^ ]*) (?<upstream_status>[^ ]*)$/
  time_format %d/%b/%Y:%H:%M:%S %z
  key_name message
  types server_port:integer,status:integer,size:integer,request_length:integer,request_time:float,upstream_response_length:integer,upstream_response_time:float,upstream_status:integer
  reserve_data yes
  suppress_parse_error_log yes
</filter>

EOF
fi

cat << EOF >> /fluentd/etc/fluent.conf
<match kubernetes.var.log.containers.$GELFDEPLOYMENT**>
  @type gelf
  host $GELFHOST
  port $GELFPORT
  flush_interval 3s
  buffer_queue_limit ${BUFFER_QUEUE_LIMIT:=4096}
  buffer_chunk_limit ${BUFFER_CHUNK_LIMIT:=2048m}
  max_retry_wait 30
  disable_retry_limit
  num_threads ${NUM_THREADS:=8}
</match>

EOF
fi
done

exec fluentd -c /fluentd/etc/fluent.conf -p /fluentd/plugins $FLUENTD_OPT
