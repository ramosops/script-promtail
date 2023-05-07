#!/bin/bash
LOG_PATH="$1"
sudo mkdir -p /opt/promtail/
cd /opt/promtail/
curl -O -L "https://github.com/grafana/loki/releases/download/v2.4.1/promtail-linux-amd64.zip"
unzip "promtail-linux-amd64.zip"
sudo chmod a+x promtail-linux-amd64
AWS_INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
EC2_NAME=$(aws ec2 describe-tags --region us-east-1 --filters "Name=resource-id,Values=$AWS_INSTANCE_ID" "Name=key,Values=Name" --output text | cut -f5)
cat << EOF > config-promtail.yml
server:
  http_listen_port: 3100
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: https://LOKI_URL_HERE/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          host: ${EC2_NAME}
          __path__: ${LOG_PATH}
EOF
sudo bash -c "cat <<EOT >> /etc/systemd/system/promtail.service
[Unit]
Description=Promtail
After=network.target
[Service]
Type=simple
User=root
ExecStart=/opt/promtail/promtail-linux-amd64 -config.file /opt/promtail/config-promtail.yml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartForceExitStatus=SIGPIPE
KillMode=control-group
[Install]
WantedBy=multi-user.target
EOT"
sudo systemctl enable promtail.service
sudo systemctl start promtail.service