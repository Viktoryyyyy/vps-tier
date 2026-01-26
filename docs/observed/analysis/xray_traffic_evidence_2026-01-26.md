# Xray traffic evidence extract (2026-01-26)

Generated (UTC): 2026-01-26T14:19:40Z
Repo branch: main
Repo HEAD: ca7c176c207f22be61e5c8b46e1a4349b36fee8c

## Snapshot dirs
```
total 16
drwxrwxr-x 4 ubuntu ubuntu 4096 Jan 26 13:56 .
drwxrwxr-x 3 ubuntu ubuntu 4096 Jan 26 13:28 ..
drwxrwxr-x 2 ubuntu ubuntu 4096 Jan 26 14:02 015445Z
drwxrwxr-x 2 ubuntu ubuntu 4096 Jan 26 13:30 132755Z
```

## Baseline file list (132755Z)
```
total 108
drwxrwxr-x 2 ubuntu ubuntu  4096 Jan 26 13:30 .
drwxrwxr-x 4 ubuntu ubuntu  4096 Jan 26 13:56 ..
-rw-rw-r-- 1 ubuntu ubuntu   348 Jan 26 13:32 certs_metadata.txt
-rw-rw-r-- 1 ubuntu ubuntu   699 Jan 26 13:30 disk.txt
-rw-rw-r-- 1 ubuntu ubuntu   360 Jan 26 13:30 dns.txt
-rw-rw-r-- 1 ubuntu ubuntu   198 Jan 26 13:30 firewall_summary.txt
-rw-rw-r-- 1 ubuntu ubuntu   494 Jan 26 13:28 identity.txt
-rw-rw-r-- 1 ubuntu ubuntu  2674 Jan 26 13:30 journals_nginx_tail.txt
-rw-rw-r-- 1 ubuntu ubuntu 21446 Jan 26 13:30 journals_tg_bot_tail.txt
-rw-rw-r-- 1 ubuntu ubuntu   120 Jan 26 13:28 meta.md
-rw-rw-r-- 1 ubuntu ubuntu   773 Jan 26 13:30 net_ifaces.txt
-rw-rw-r-- 1 ubuntu ubuntu   120 Jan 26 13:30 net_routes.txt
-rw-rw-r-- 1 ubuntu ubuntu  9672 Jan 26 13:30 processes.txt
-rw-rw-r-- 1 ubuntu ubuntu   278 Jan 26 13:30 resources.txt
-rw-rw-r-- 1 ubuntu ubuntu  6120 Jan 26 13:30 sockets.txt
-rw-rw-r-- 1 ubuntu ubuntu  2608 Jan 26 13:29 systemd_timers.txt
-rw-rw-r-- 1 ubuntu ubuntu  4469 Jan 26 13:29 systemd_units.txt
-rw-rw-r-- 1 ubuntu ubuntu   337 Jan 26 13:29 time.txt
```

## Snapshot#2 file list (015445Z)
```
total 200
drwxrwxr-x 2 ubuntu ubuntu  4096 Jan 26 14:02 .
drwxrwxr-x 4 ubuntu ubuntu  4096 Jan 26 13:56 ..
-rw-rw-r-- 1 ubuntu ubuntu 24400 Jan 26 13:59 connections_head200.txt
-rw-rw-r-- 1 ubuntu ubuntu   699 Jan 26 13:59 disk.txt
-rw-rw-r-- 1 ubuntu ubuntu   360 Jan 26 13:59 dns.txt
-rw-rw-r-- 1 ubuntu ubuntu   198 Jan 26 13:59 firewall_summary.txt
-rw-rw-r-- 1 ubuntu ubuntu   494 Jan 26 13:56 identity.txt
-rw-rw-r-- 1 ubuntu ubuntu  2674 Jan 26 13:59 journals_nginx_tail.txt
-rw-rw-r-- 1 ubuntu ubuntu 21446 Jan 26 13:59 journals_tg_bot_tail.txt
-rw-rw-r-- 1 ubuntu ubuntu 41715 Jan 26 13:59 journals_xray_tail.txt
-rw-rw-r-- 1 ubuntu ubuntu   153 Jan 26 13:56 meta.md
-rw-rw-r-- 1 ubuntu ubuntu   158 Jan 26 13:59 net_ifaces_brief.txt
-rw-rw-r-- 1 ubuntu ubuntu   773 Jan 26 13:59 net_ifaces.txt
-rw-rw-r-- 1 ubuntu ubuntu    84 Jan 26 13:59 net_ip_rules.txt
-rw-rw-r-- 1 ubuntu ubuntu   825 Jan 26 13:59 net_link_counters.txt
-rw-rw-r-- 1 ubuntu ubuntu   120 Jan 26 13:59 net_routes_main.txt
-rw-rw-r-- 1 ubuntu ubuntu  9672 Jan 26 13:59 processes.txt
-rw-rw-r-- 1 ubuntu ubuntu   278 Jan 26 13:59 resources.txt
-rw-rw-r-- 1 ubuntu ubuntu 11304 Jan 26 13:59 sockets_tcp_listen.txt
-rw-rw-r-- 1 ubuntu ubuntu  9900 Jan 26 13:59 sockets_udp.txt
-rw-rw-r-- 1 ubuntu ubuntu  2608 Jan 26 13:59 systemd_timers.txt
-rw-rw-r-- 1 ubuntu ubuntu  6234 Jan 26 13:59 systemd_xray_show.txt
-rw-rw-r-- 1 ubuntu ubuntu   337 Jan 26 13:56 time.txt
```

## Port ownership (:443 / :8443) BASELINE
```
81:tcp   LISTEN 0      511          0.0.0.0:8443       0.0.0.0:*          
85:tcp   LISTEN 0      4096               *:443              *:*          
```

## Port ownership (:443 / :8443) SNAP2
```
docs/observed/snapshots/2026-01-26/015445Z/sockets_tcp_listen.txt:153:tcp   LISTEN 0      511          0.0.0.0:8443       0.0.0.0:*          
docs/observed/snapshots/2026-01-26/015445Z/sockets_tcp_listen.txt:157:tcp   LISTEN 0      4096               *:443              *:*          
```

## Xray unit status lines (BASELINE)
```
7:● xray.service - Xray Service
8:     Loaded: loaded (/etc/systemd/system/xray.service; enabled; vendor preset: enabled)
11:     Active: active (running) since Thu 2026-01-22 09:41:31 UTC; 4 days ago
13:   Main PID: 2170 (xray)
32:     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
33:     Active: active (running) since Thu 2026-01-22 09:32:30 UTC; 4 days ago
36:    Process: 793 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
37:   Main PID: 801 (nginx)
50:     Loaded: loaded (/etc/systemd/system/tg-bot.service; enabled; vendor preset: enabled)
51:     Active: active (running) since Thu 2026-01-22 09:32:29 UTC; 4 days ago
52:   Main PID: 742 (python)
62:     Loaded: loaded (/etc/systemd/system/tier1-health.timer; enabled; vendor preset: enabled)
63:     Active: active (waiting) since Thu 2026-01-22 09:32:29 UTC; 4 days ago
70:     Loaded: loaded (/etc/systemd/system/tier1-alert.timer; enabled; vendor preset: enabled)
71:     Active: active (waiting) since Thu 2026-01-22 09:32:29 UTC; 4 days ago
```

## Xray unit status lines (SNAP2)
```
```

## Xray systemd show key fields (SNAP2)
```
18:MainPID=2170
37:ExecStart={ path=/usr/local/bin/xray ; argv[]=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json ; ignore_errors=no ; start_time=[Thu 2026-01-22 09:41:31 UTC] ; stop_time=[n/a] ; pid=2170 ; code=(null) ; status=0/0 }
147:User=nobody
205:FragmentPath=/etc/systemd/system/xray.service
```

## Xray journal: error keywords (BASELINE)
```
```

## Xray journal: error keywords (SNAP2)
```
2:Jan 26 13:56:09 33701 xray[2170]: 2026/01/26 13:56:09.748128 from 213.87.161.52:23530 accepted udp:api.termius.com:443 [vless443 >> direct]
4:Jan 26 13:56:10 33701 xray[2170]: 2026/01/26 13:56:10.058719 from 46.138.236.102:1031 accepted udp:accounts.google.com:443 [vless443 >> direct]
8:Jan 26 13:56:14 33701 xray[2170]: 2026/01/26 13:56:14.404920 from 213.87.161.52:8204 accepted udp:chatgpt.com:443 [vless443 >> direct]
9:Jan 26 13:56:14 33701 xray[2170]: 2026/01/26 13:56:14.471223 from 213.87.161.52:20430 accepted udp:chatgpt.com:443 [vless443 >> direct]
16:Jan 26 13:56:16 33701 xray[2170]: 2026/01/26 13:56:16.040126 from 213.87.161.52:26383 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
18:Jan 26 13:56:16 33701 xray[2170]: 2026/01/26 13:56:16.528171 from 213.87.161.52:13403 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
26:Jan 26 13:56:24 33701 xray[2170]: 2026/01/26 13:56:24.381872 from 213.87.161.52:10916 accepted udp:api.termius.com:443 [vless443 >> direct]
27:Jan 26 13:56:24 33701 xray[2170]: 2026/01/26 13:56:24.533235 from 213.87.161.52:10901 accepted udp:api.termius.com:443 [vless443 >> direct]
32:Jan 26 13:56:29 33701 xray[2170]: 2026/01/26 13:56:29.587817 from 213.87.161.52:9151 accepted udp:chatgpt.com:443 [vless443 >> direct]
33:Jan 26 13:56:29 33701 xray[2170]: 2026/01/26 13:56:29.589700 from 213.87.161.52:9800 accepted udp:chatgpt.com:443 [vless443 >> direct]
37:Jan 26 13:56:30 33701 xray[2170]: 2026/01/26 13:56:30.762856 from 46.138.236.102:2456 accepted udp:i.ytimg.com:443 [vless443 >> direct]
38:Jan 26 13:56:30 33701 xray[2170]: 2026/01/26 13:56:30.886868 from 46.138.236.102:2458 accepted udp:i.ytimg.com:443 [vless443 >> direct]
40:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.181625 from 46.138.236.102:2460 accepted udp:i.ytimg.com:443 [vless443 >> direct]
41:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.303170 from 46.138.236.102:2461 accepted udp:i.ytimg.com:443 [vless443 >> direct]
42:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.356018 from 46.138.236.102:2462 accepted udp:i.ytimg.com:443 [vless443 >> direct]
43:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.449141 from 46.138.236.102:2463 accepted udp:i.ytimg.com:443 [vless443 >> direct]
44:Jan 26 13:56:32 33701 xray[2170]: 2026/01/26 13:56:32.037793 from 213.87.161.52:5873 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
46:Jan 26 13:56:32 33701 xray[2170]: 2026/01/26 13:56:32.069713 from 213.87.161.52:2409 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
56:Jan 26 13:56:42 33701 xray[2170]: 2026/01/26 13:56:42.783112 from 213.87.161.52:28965 accepted udp:api.termius.com:443 [vless443 >> direct]
57:Jan 26 13:56:42 33701 xray[2170]: 2026/01/26 13:56:42.943944 from 213.87.161.52:27490 accepted udp:api.termius.com:443 [vless443 >> direct]
63:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.088459 from 213.87.161.153:17538 accepted udp:tether.edge.apple:443 [vless443 >> direct]
64:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.911007 from 213.87.161.52:6187 accepted udp:chatgpt.com:443 [vless443 >> direct]
66:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.957113 from 213.87.161.52:9249 accepted udp:chatgpt.com:443 [vless443 >> direct]
67:Jan 26 13:56:48 33701 xray[2170]: 2026/01/26 13:56:48.084147 from 213.87.161.153:12200 accepted udp:17.253.18.237:443 [vless443 >> direct]
71:Jan 26 13:56:49 33701 xray[2170]: 2026/01/26 13:56:49.810128 from 213.87.161.52:12099 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
72:Jan 26 13:56:49 33701 xray[2170]: 2026/01/26 13:56:49.998781 from 213.87.161.52:1456 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
83:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.026878 from 46.138.236.102:1229 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
85:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.131274 from 46.138.236.102:1233 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
86:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.133148 from 46.138.236.102:1232 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
87:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288231 from 46.138.236.102:1237 accepted udp:fonts.gstatic.com:443 [vless443 >> direct]
88:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288951 from 46.138.236.102:1235 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
89:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288967 from 46.138.236.102:1234 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
91:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.360305 from 46.138.236.102:1242 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
92:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.368809 from 46.138.236.102:1241 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
94:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.413831 from 46.138.236.102:1244 accepted udp:fonts.gstatic.com:443 [vless443 >> direct]
95:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.490000 from 46.138.236.102:1245 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
97:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.494979 from 46.138.236.102:1246 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
98:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.576078 from 46.138.236.102:1248 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
99:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.605272 from 46.138.236.102:1247 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
101:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.660450 from 46.138.236.102:1251 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
102:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.662090 from 213.87.161.52:9782 accepted udp:api.termius.com:443 [vless443 >> direct]
103:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.682549 from 213.87.161.52:10607 accepted udp:api.termius.com:443 [vless443 >> direct]
104:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.948996 from 46.138.236.102:1252 accepted udp:www.google.com:443 [vless443 >> direct]
105:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.083659 from 46.138.236.102:1253 accepted udp:www.google.com:443 [vless443 >> direct]
107:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.178251 from 46.138.236.102:1255 accepted udp:www.google.com:443 [vless443 >> direct]
108:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.291191 from 46.138.236.102:1258 accepted udp:www.google.com:443 [vless443 >> direct]
109:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.403710 from 46.138.236.102:1259 accepted udp:www.google.com:443 [vless443 >> direct]
110:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.522202 from 46.138.236.102:1260 accepted udp:www.google.com:443 [vless443 >> direct]
112:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.813314 from 46.138.236.102:1262 accepted udp:www.google.ru:443 [vless443 >> direct]
114:Jan 26 13:56:59 33701 xray[2170]: 2026/01/26 13:56:59.809640 from 46.138.236.102:1264 accepted udp:1.1.1.1:53 [vless443 >> direct]
115:Jan 26 13:56:59 33701 xray[2170]: 2026/01/26 13:56:59.816260 from 46.138.236.102:1265 accepted udp:1.1.1.1:53 [vless443 >> direct]
116:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.217183 from 46.138.236.102:1267 accepted tcp:chrome.cloudflare-dns.com:443 [vless443 >> direct]
117:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.822050 from 46.138.236.102:1271 accepted udp:1.1.1.1:53 [vless443 >> direct]
119:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.880409 from 46.138.236.102:1269 accepted udp:1.1.1.1:53 [vless443 >> direct]
121:Jan 26 13:57:01 33701 xray[2170]: 2026/01/26 13:57:01.264956 from 46.138.236.102:1277 accepted tcp:dns.google:443 [vless443 >> direct]
122:Jan 26 13:57:01 33701 xray[2170]: 2026/01/26 13:57:01.265021 from 46.138.236.102:1275 accepted tcp:dns.google:443 [vless443 >> direct]
127:Jan 26 13:57:03 33701 xray[2170]: 2026/01/26 13:57:03.006690 from 213.87.161.52:19563 accepted udp:chatgpt.com:443 [vless443 >> direct]
128:Jan 26 13:57:03 33701 xray[2170]: 2026/01/26 13:57:03.186083 from 213.87.161.52:24248 accepted udp:chatgpt.com:443 [vless443 >> direct]
132:Jan 26 13:57:05 33701 xray[2170]: 2026/01/26 13:57:05.087885 from 213.87.161.52:20504 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
133:Jan 26 13:57:05 33701 xray[2170]: 2026/01/26 13:57:05.182855 from 213.87.161.52:32293 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
140:Jan 26 13:57:08 33701 xray[2170]: 2026/01/26 13:57:08.947353 from 46.138.236.102:2317 accepted udp:rr18---sn-n8v7znlk.googlevideo.com:443 [vless443 >> direct]
143:Jan 26 13:57:09 33701 xray[2170]: 2026/01/26 13:57:09.433230 from 46.138.236.102:2319 accepted udp:rr4---sn-n8v7sney.googlevideo.com:443 [vless443 >> direct]
145:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.319222 from 46.138.236.102:2323 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
147:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.530264 from 46.138.236.102:2325 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
148:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.961836 from 46.138.236.102:2326 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
163:Jan 26 13:57:28 33701 xray[2170]: 2026/01/26 13:57:28.891194 from 46.138.236.102:1270 accepted udp:r1---sn-8ph2xajvh-3w5l.googlevideo.com:443 [vless443 >> direct]
165:Jan 26 13:57:29 33701 xray[2170]: 2026/01/26 13:57:29.728811 from 46.138.236.102:1030 accepted udp:ssl.gstatic.com:443 [vless443 >> direct]
178:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.365487 from 213.87.161.52:2238 accepted udp:api.termius.com:443 [vless443 >> direct]
180:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.373601 from 213.87.161.52:19542 accepted udp:api.termius.com:443 [vless443 >> direct]
181:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.516338 from 213.87.161.52:11445 accepted udp:sentry.io:443 [vless443 >> direct]
198:Jan 26 13:58:02 33701 xray[2170]: 2026/01/26 13:58:02.362693 from 213.87.161.52:6936 accepted udp:chatgpt.com:443 [vless443 >> direct]
199:Jan 26 13:58:02 33701 xray[2170]: 2026/01/26 13:58:02.518894 from 213.87.161.52:22067 accepted udp:chatgpt.com:443 [vless443 >> direct]
219:Jan 26 13:58:15 33701 xray[2170]: 2026/01/26 13:58:15.188569 from 213.87.161.52:5220 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
220:Jan 26 13:58:15 33701 xray[2170]: 2026/01/26 13:58:15.477245 from 213.87.161.52:23530 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
228:Jan 26 13:58:22 33701 xray[2170]: 2026/01/26 13:58:22.905573 from 213.87.161.52:20137 accepted udp:api.termius.com:443 [vless443 >> direct]
229:Jan 26 13:58:23 33701 xray[2170]: 2026/01/26 13:58:23.073586 from 213.87.161.52:7575 accepted udp:api.termius.com:443 [vless443 >> direct]
234:Jan 26 13:58:27 33701 xray[2170]: 2026/01/26 13:58:27.016203 from 213.87.161.52:23239 accepted udp:chatgpt.com:443 [vless443 >> direct]
236:Jan 26 13:58:27 33701 xray[2170]: 2026/01/26 13:58:27.029028 from 213.87.161.52:31240 accepted udp:chatgpt.com:443 [vless443 >> direct]
240:Jan 26 13:58:30 33701 xray[2170]: 2026/01/26 13:58:30.326965 from 213.87.161.52:11358 accepted udp:api.termius.com:443 [vless443 >> direct]
243:Jan 26 13:58:30 33701 xray[2170]: 2026/01/26 13:58:30.479075 from 213.87.161.52:28364 accepted udp:api.termius.com:443 [vless443 >> direct]
259:Jan 26 13:58:47 33701 xray[2170]: 2026/01/26 13:58:47.278715 from tcp:213.87.161.52:16212 accepted udp:17.253.38.35:123 [vless443 >> direct]
264:Jan 26 13:58:53 33701 xray[2170]: 2026/01/26 13:58:53.614821 from 213.87.161.52:2829 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
265:Jan 26 13:58:53 33701 xray[2170]: 2026/01/26 13:58:53.682457 from 213.87.161.52:11202 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
276:Jan 26 13:59:02 33701 xray[2170]: 2026/01/26 13:59:02.737911 from 213.87.161.52:28362 accepted udp:api.termius.com:443 [vless443 >> direct]
279:Jan 26 13:59:02 33701 xray[2170]: 2026/01/26 13:59:02.907597 from 213.87.161.52:22280 accepted udp:api.termius.com:443 [vless443 >> direct]
293:Jan 26 13:59:25 33701 xray[2170]: 2026/01/26 13:59:25.628628 from 213.87.161.52:29914 accepted udp:api.termius.com:443 [vless443 >> direct]
294:Jan 26 13:59:25 33701 xray[2170]: 2026/01/26 13:59:25.636892 from 213.87.161.52:16220 accepted udp:api.termius.com:443 [vless443 >> direct]
```

## Routes main (BASELINE, first 200 lines)
```
```

## Routes main (SNAP2, first 200 lines)
```
default via 194.32.142.1 dev enp3s0 proto static 
194.32.142.0/24 dev enp3s0 proto kernel scope link src 194.32.142.88 
```

## IP rules (SNAP2, first 200 lines)
```
0:	from all lookup local
32766:	from all lookup main
32767:	from all lookup default
```

## Firewall summary head (BASELINE, first 200 lines)
```
ERROR: You need to be root to run this script

iptables v1.8.7 (nf_tables): Could not fetch rule set generation id: Permission denied (you must be root)


Operation not permitted (you must be root)
```

## Firewall summary head (SNAP2, first 200 lines)
```
ERROR: You need to be root to run this script

iptables v1.8.7 (nf_tables): Could not fetch rule set generation id: Permission denied (you must be root)


Operation not permitted (you must be root)
```

## Link counters (BASELINE, first 200 lines)
```
```

## Link counters (SNAP2, first 200 lines)
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    RX:  bytes packets errors dropped  missed   mcast           
     161585560 1448777      0       0       0       0 
    TX:  bytes packets errors dropped carrier collsns           
     161585560 1448777      0       0       0       0 
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether fa:16:3e:c1:24:b5 brd ff:ff:ff:ff:ff:ff
    RX:   bytes   packets errors dropped  missed   mcast           
    67355389988 163376931      0       0       0       0 
    TX:   bytes   packets errors dropped carrier collsns           
    55351015762  37417665      0       0       0       0 
```
