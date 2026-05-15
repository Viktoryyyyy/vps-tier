# Hysteria2 systemd unit template
#
# Render target, later apply phase only:
#   .render/systemd/hysteria-server.service -> /etc/systemd/system/hysteria-server.service
#
# Scope: Hysteria2 only. This unit must not manage xray, nginx, ssh, certbot,
# firewall, reboot, package installation, or runtime secret generation.

[Unit]
Description=Hysteria2 Backup VPN Server
Documentation=https://v2.hysteria.network/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=${VPS_HYSTERIA2_BIN_PATH} server -c /etc/hysteria/server.yaml
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=/etc/hysteria /var/log

[Install]
WantedBy=multi-user.target
