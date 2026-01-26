# Xray traffic — factual diff v1

Source evidence:
- docs/observed/analysis/xray_traffic_evidence_2026-01-26.md

## Port / listener ownership
```
67:## Port ownership (:443 / :8443) BASELINE
69:81:tcp   LISTEN 0      511          0.0.0.0:8443       0.0.0.0:*          
70:85:tcp   LISTEN 0      4096               *:443              *:*          
73:## Port ownership (:443 / :8443) SNAP2
75:docs/observed/snapshots/2026-01-26/015445Z/sockets_tcp_listen.txt:153:tcp   LISTEN 0      511          0.0.0.0:8443       0.0.0.0:*          
76:docs/observed/snapshots/2026-01-26/015445Z/sockets_tcp_listen.txt:157:tcp   LISTEN 0      4096               *:443              *:*          
116:2:Jan 26 13:56:09 33701 xray[2170]: 2026/01/26 13:56:09.748128 from 213.87.161.52:23530 accepted udp:api.termius.com:443 [vless443 >> direct]
117:4:Jan 26 13:56:10 33701 xray[2170]: 2026/01/26 13:56:10.058719 from 46.138.236.102:1031 accepted udp:accounts.google.com:443 [vless443 >> direct]
118:8:Jan 26 13:56:14 33701 xray[2170]: 2026/01/26 13:56:14.404920 from 213.87.161.52:8204 accepted udp:chatgpt.com:443 [vless443 >> direct]
119:9:Jan 26 13:56:14 33701 xray[2170]: 2026/01/26 13:56:14.471223 from 213.87.161.52:20430 accepted udp:chatgpt.com:443 [vless443 >> direct]
120:16:Jan 26 13:56:16 33701 xray[2170]: 2026/01/26 13:56:16.040126 from 213.87.161.52:26383 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
121:18:Jan 26 13:56:16 33701 xray[2170]: 2026/01/26 13:56:16.528171 from 213.87.161.52:13403 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
122:26:Jan 26 13:56:24 33701 xray[2170]: 2026/01/26 13:56:24.381872 from 213.87.161.52:10916 accepted udp:api.termius.com:443 [vless443 >> direct]
123:27:Jan 26 13:56:24 33701 xray[2170]: 2026/01/26 13:56:24.533235 from 213.87.161.52:10901 accepted udp:api.termius.com:443 [vless443 >> direct]
124:32:Jan 26 13:56:29 33701 xray[2170]: 2026/01/26 13:56:29.587817 from 213.87.161.52:9151 accepted udp:chatgpt.com:443 [vless443 >> direct]
125:33:Jan 26 13:56:29 33701 xray[2170]: 2026/01/26 13:56:29.589700 from 213.87.161.52:9800 accepted udp:chatgpt.com:443 [vless443 >> direct]
126:37:Jan 26 13:56:30 33701 xray[2170]: 2026/01/26 13:56:30.762856 from 46.138.236.102:2456 accepted udp:i.ytimg.com:443 [vless443 >> direct]
127:38:Jan 26 13:56:30 33701 xray[2170]: 2026/01/26 13:56:30.886868 from 46.138.236.102:2458 accepted udp:i.ytimg.com:443 [vless443 >> direct]
128:40:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.181625 from 46.138.236.102:2460 accepted udp:i.ytimg.com:443 [vless443 >> direct]
129:41:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.303170 from 46.138.236.102:2461 accepted udp:i.ytimg.com:443 [vless443 >> direct]
130:42:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.356018 from 46.138.236.102:2462 accepted udp:i.ytimg.com:443 [vless443 >> direct]
131:43:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.449141 from 46.138.236.102:2463 accepted udp:i.ytimg.com:443 [vless443 >> direct]
132:44:Jan 26 13:56:32 33701 xray[2170]: 2026/01/26 13:56:32.037793 from 213.87.161.52:5873 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
133:46:Jan 26 13:56:32 33701 xray[2170]: 2026/01/26 13:56:32.069713 from 213.87.161.52:2409 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
134:56:Jan 26 13:56:42 33701 xray[2170]: 2026/01/26 13:56:42.783112 from 213.87.161.52:28965 accepted udp:api.termius.com:443 [vless443 >> direct]
135:57:Jan 26 13:56:42 33701 xray[2170]: 2026/01/26 13:56:42.943944 from 213.87.161.52:27490 accepted udp:api.termius.com:443 [vless443 >> direct]
136:63:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.088459 from 213.87.161.153:17538 accepted udp:tether.edge.apple:443 [vless443 >> direct]
137:64:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.911007 from 213.87.161.52:6187 accepted udp:chatgpt.com:443 [vless443 >> direct]
138:66:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.957113 from 213.87.161.52:9249 accepted udp:chatgpt.com:443 [vless443 >> direct]
139:67:Jan 26 13:56:48 33701 xray[2170]: 2026/01/26 13:56:48.084147 from 213.87.161.153:12200 accepted udp:17.253.18.237:443 [vless443 >> direct]
140:71:Jan 26 13:56:49 33701 xray[2170]: 2026/01/26 13:56:49.810128 from 213.87.161.52:12099 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
141:72:Jan 26 13:56:49 33701 xray[2170]: 2026/01/26 13:56:49.998781 from 213.87.161.52:1456 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
142:83:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.026878 from 46.138.236.102:1229 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
143:85:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.131274 from 46.138.236.102:1233 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
144:86:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.133148 from 46.138.236.102:1232 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
145:87:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288231 from 46.138.236.102:1237 accepted udp:fonts.gstatic.com:443 [vless443 >> direct]
146:88:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288951 from 46.138.236.102:1235 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
147:89:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288967 from 46.138.236.102:1234 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
148:91:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.360305 from 46.138.236.102:1242 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
149:92:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.368809 from 46.138.236.102:1241 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
150:94:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.413831 from 46.138.236.102:1244 accepted udp:fonts.gstatic.com:443 [vless443 >> direct]
151:95:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.490000 from 46.138.236.102:1245 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
152:97:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.494979 from 46.138.236.102:1246 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
153:98:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.576078 from 46.138.236.102:1248 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
154:99:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.605272 from 46.138.236.102:1247 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
155:101:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.660450 from 46.138.236.102:1251 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
156:102:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.662090 from 213.87.161.52:9782 accepted udp:api.termius.com:443 [vless443 >> direct]
157:103:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.682549 from 213.87.161.52:10607 accepted udp:api.termius.com:443 [vless443 >> direct]
158:104:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.948996 from 46.138.236.102:1252 accepted udp:www.google.com:443 [vless443 >> direct]
159:105:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.083659 from 46.138.236.102:1253 accepted udp:www.google.com:443 [vless443 >> direct]
160:107:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.178251 from 46.138.236.102:1255 accepted udp:www.google.com:443 [vless443 >> direct]
161:108:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.291191 from 46.138.236.102:1258 accepted udp:www.google.com:443 [vless443 >> direct]
162:109:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.403710 from 46.138.236.102:1259 accepted udp:www.google.com:443 [vless443 >> direct]
163:110:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.522202 from 46.138.236.102:1260 accepted udp:www.google.com:443 [vless443 >> direct]
164:112:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.813314 from 46.138.236.102:1262 accepted udp:www.google.ru:443 [vless443 >> direct]
167:116:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.217183 from 46.138.236.102:1267 accepted tcp:chrome.cloudflare-dns.com:443 [vless443 >> direct]
170:121:Jan 26 13:57:01 33701 xray[2170]: 2026/01/26 13:57:01.264956 from 46.138.236.102:1277 accepted tcp:dns.google:443 [vless443 >> direct]
171:122:Jan 26 13:57:01 33701 xray[2170]: 2026/01/26 13:57:01.265021 from 46.138.236.102:1275 accepted tcp:dns.google:443 [vless443 >> direct]
172:127:Jan 26 13:57:03 33701 xray[2170]: 2026/01/26 13:57:03.006690 from 213.87.161.52:19563 accepted udp:chatgpt.com:443 [vless443 >> direct]
173:128:Jan 26 13:57:03 33701 xray[2170]: 2026/01/26 13:57:03.186083 from 213.87.161.52:24248 accepted udp:chatgpt.com:443 [vless443 >> direct]
174:132:Jan 26 13:57:05 33701 xray[2170]: 2026/01/26 13:57:05.087885 from 213.87.161.52:20504 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
175:133:Jan 26 13:57:05 33701 xray[2170]: 2026/01/26 13:57:05.182855 from 213.87.161.52:32293 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
176:140:Jan 26 13:57:08 33701 xray[2170]: 2026/01/26 13:57:08.947353 from 46.138.236.102:2317 accepted udp:rr18---sn-n8v7znlk.googlevideo.com:443 [vless443 >> direct]
177:143:Jan 26 13:57:09 33701 xray[2170]: 2026/01/26 13:57:09.433230 from 46.138.236.102:2319 accepted udp:rr4---sn-n8v7sney.googlevideo.com:443 [vless443 >> direct]
178:145:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.319222 from 46.138.236.102:2323 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
179:147:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.530264 from 46.138.236.102:2325 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
180:148:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.961836 from 46.138.236.102:2326 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
181:163:Jan 26 13:57:28 33701 xray[2170]: 2026/01/26 13:57:28.891194 from 46.138.236.102:1270 accepted udp:r1---sn-8ph2xajvh-3w5l.googlevideo.com:443 [vless443 >> direct]
182:165:Jan 26 13:57:29 33701 xray[2170]: 2026/01/26 13:57:29.728811 from 46.138.236.102:1030 accepted udp:ssl.gstatic.com:443 [vless443 >> direct]
183:178:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.365487 from 213.87.161.52:2238 accepted udp:api.termius.com:443 [vless443 >> direct]
184:180:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.373601 from 213.87.161.52:19542 accepted udp:api.termius.com:443 [vless443 >> direct]
185:181:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.516338 from 213.87.161.52:11445 accepted udp:sentry.io:443 [vless443 >> direct]
186:198:Jan 26 13:58:02 33701 xray[2170]: 2026/01/26 13:58:02.362693 from 213.87.161.52:6936 accepted udp:chatgpt.com:443 [vless443 >> direct]
187:199:Jan 26 13:58:02 33701 xray[2170]: 2026/01/26 13:58:02.518894 from 213.87.161.52:22067 accepted udp:chatgpt.com:443 [vless443 >> direct]
188:219:Jan 26 13:58:15 33701 xray[2170]: 2026/01/26 13:58:15.188569 from 213.87.161.52:5220 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
189:220:Jan 26 13:58:15 33701 xray[2170]: 2026/01/26 13:58:15.477245 from 213.87.161.52:23530 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
190:228:Jan 26 13:58:22 33701 xray[2170]: 2026/01/26 13:58:22.905573 from 213.87.161.52:20137 accepted udp:api.termius.com:443 [vless443 >> direct]
191:229:Jan 26 13:58:23 33701 xray[2170]: 2026/01/26 13:58:23.073586 from 213.87.161.52:7575 accepted udp:api.termius.com:443 [vless443 >> direct]
192:234:Jan 26 13:58:27 33701 xray[2170]: 2026/01/26 13:58:27.016203 from 213.87.161.52:23239 accepted udp:chatgpt.com:443 [vless443 >> direct]
193:236:Jan 26 13:58:27 33701 xray[2170]: 2026/01/26 13:58:27.029028 from 213.87.161.52:31240 accepted udp:chatgpt.com:443 [vless443 >> direct]
194:240:Jan 26 13:58:30 33701 xray[2170]: 2026/01/26 13:58:30.326965 from 213.87.161.52:11358 accepted udp:api.termius.com:443 [vless443 >> direct]
195:243:Jan 26 13:58:30 33701 xray[2170]: 2026/01/26 13:58:30.479075 from 213.87.161.52:28364 accepted udp:api.termius.com:443 [vless443 >> direct]
197:264:Jan 26 13:58:53 33701 xray[2170]: 2026/01/26 13:58:53.614821 from 213.87.161.52:2829 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
198:265:Jan 26 13:58:53 33701 xray[2170]: 2026/01/26 13:58:53.682457 from 213.87.161.52:11202 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
199:276:Jan 26 13:59:02 33701 xray[2170]: 2026/01/26 13:59:02.737911 from 213.87.161.52:28362 accepted udp:api.termius.com:443 [vless443 >> direct]
200:279:Jan 26 13:59:02 33701 xray[2170]: 2026/01/26 13:59:02.907597 from 213.87.161.52:22280 accepted udp:api.termius.com:443 [vless443 >> direct]
201:293:Jan 26 13:59:25 33701 xray[2170]: 2026/01/26 13:59:25.628628 from 213.87.161.52:29914 accepted udp:api.termius.com:443 [vless443 >> direct]
202:294:Jan 26 13:59:25 33701 xray[2170]: 2026/01/26 13:59:25.636892 from 213.87.161.52:16220 accepted udp:api.termius.com:443 [vless443 >> direct]
```

## Xray journal error keywords
```
23:-rw-rw-r-- 1 ubuntu ubuntu   360 Jan 26 13:30 dns.txt
30:-rw-rw-r-- 1 ubuntu ubuntu   120 Jan 26 13:30 net_routes.txt
46:-rw-rw-r-- 1 ubuntu ubuntu   360 Jan 26 13:59 dns.txt
57:-rw-rw-r-- 1 ubuntu ubuntu   120 Jan 26 13:59 net_routes_main.txt
61:-rw-rw-r-- 1 ubuntu ubuntu  9900 Jan 26 13:59 sockets_udp.txt
105:37:ExecStart={ path=/usr/local/bin/xray ; argv[]=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json ; ignore_errors=no ; start_time=[Thu 2026-01-22 09:41:31 UTC] ; stop_time=[n/a] ; pid=2170 ; code=(null) ; status=0/0 }
110:## Xray journal: error keywords (BASELINE)
114:## Xray journal: error keywords (SNAP2)
116:2:Jan 26 13:56:09 33701 xray[2170]: 2026/01/26 13:56:09.748128 from 213.87.161.52:23530 accepted udp:api.termius.com:443 [vless443 >> direct]
117:4:Jan 26 13:56:10 33701 xray[2170]: 2026/01/26 13:56:10.058719 from 46.138.236.102:1031 accepted udp:accounts.google.com:443 [vless443 >> direct]
118:8:Jan 26 13:56:14 33701 xray[2170]: 2026/01/26 13:56:14.404920 from 213.87.161.52:8204 accepted udp:chatgpt.com:443 [vless443 >> direct]
119:9:Jan 26 13:56:14 33701 xray[2170]: 2026/01/26 13:56:14.471223 from 213.87.161.52:20430 accepted udp:chatgpt.com:443 [vless443 >> direct]
120:16:Jan 26 13:56:16 33701 xray[2170]: 2026/01/26 13:56:16.040126 from 213.87.161.52:26383 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
121:18:Jan 26 13:56:16 33701 xray[2170]: 2026/01/26 13:56:16.528171 from 213.87.161.52:13403 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
122:26:Jan 26 13:56:24 33701 xray[2170]: 2026/01/26 13:56:24.381872 from 213.87.161.52:10916 accepted udp:api.termius.com:443 [vless443 >> direct]
123:27:Jan 26 13:56:24 33701 xray[2170]: 2026/01/26 13:56:24.533235 from 213.87.161.52:10901 accepted udp:api.termius.com:443 [vless443 >> direct]
124:32:Jan 26 13:56:29 33701 xray[2170]: 2026/01/26 13:56:29.587817 from 213.87.161.52:9151 accepted udp:chatgpt.com:443 [vless443 >> direct]
125:33:Jan 26 13:56:29 33701 xray[2170]: 2026/01/26 13:56:29.589700 from 213.87.161.52:9800 accepted udp:chatgpt.com:443 [vless443 >> direct]
126:37:Jan 26 13:56:30 33701 xray[2170]: 2026/01/26 13:56:30.762856 from 46.138.236.102:2456 accepted udp:i.ytimg.com:443 [vless443 >> direct]
127:38:Jan 26 13:56:30 33701 xray[2170]: 2026/01/26 13:56:30.886868 from 46.138.236.102:2458 accepted udp:i.ytimg.com:443 [vless443 >> direct]
128:40:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.181625 from 46.138.236.102:2460 accepted udp:i.ytimg.com:443 [vless443 >> direct]
129:41:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.303170 from 46.138.236.102:2461 accepted udp:i.ytimg.com:443 [vless443 >> direct]
130:42:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.356018 from 46.138.236.102:2462 accepted udp:i.ytimg.com:443 [vless443 >> direct]
131:43:Jan 26 13:56:31 33701 xray[2170]: 2026/01/26 13:56:31.449141 from 46.138.236.102:2463 accepted udp:i.ytimg.com:443 [vless443 >> direct]
132:44:Jan 26 13:56:32 33701 xray[2170]: 2026/01/26 13:56:32.037793 from 213.87.161.52:5873 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
133:46:Jan 26 13:56:32 33701 xray[2170]: 2026/01/26 13:56:32.069713 from 213.87.161.52:2409 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
134:56:Jan 26 13:56:42 33701 xray[2170]: 2026/01/26 13:56:42.783112 from 213.87.161.52:28965 accepted udp:api.termius.com:443 [vless443 >> direct]
135:57:Jan 26 13:56:42 33701 xray[2170]: 2026/01/26 13:56:42.943944 from 213.87.161.52:27490 accepted udp:api.termius.com:443 [vless443 >> direct]
136:63:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.088459 from 213.87.161.153:17538 accepted udp:tether.edge.apple:443 [vless443 >> direct]
137:64:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.911007 from 213.87.161.52:6187 accepted udp:chatgpt.com:443 [vless443 >> direct]
138:66:Jan 26 13:56:47 33701 xray[2170]: 2026/01/26 13:56:47.957113 from 213.87.161.52:9249 accepted udp:chatgpt.com:443 [vless443 >> direct]
139:67:Jan 26 13:56:48 33701 xray[2170]: 2026/01/26 13:56:48.084147 from 213.87.161.153:12200 accepted udp:17.253.18.237:443 [vless443 >> direct]
140:71:Jan 26 13:56:49 33701 xray[2170]: 2026/01/26 13:56:49.810128 from 213.87.161.52:12099 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
141:72:Jan 26 13:56:49 33701 xray[2170]: 2026/01/26 13:56:49.998781 from 213.87.161.52:1456 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
142:83:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.026878 from 46.138.236.102:1229 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
143:85:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.131274 from 46.138.236.102:1233 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
144:86:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.133148 from 46.138.236.102:1232 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
145:87:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288231 from 46.138.236.102:1237 accepted udp:fonts.gstatic.com:443 [vless443 >> direct]
146:88:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288951 from 46.138.236.102:1235 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
147:89:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.288967 from 46.138.236.102:1234 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
148:91:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.360305 from 46.138.236.102:1242 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
149:92:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.368809 from 46.138.236.102:1241 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
150:94:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.413831 from 46.138.236.102:1244 accepted udp:fonts.gstatic.com:443 [vless443 >> direct]
151:95:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.490000 from 46.138.236.102:1245 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
152:97:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.494979 from 46.138.236.102:1246 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
153:98:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.576078 from 46.138.236.102:1248 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
154:99:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.605272 from 46.138.236.102:1247 accepted udp:yt3.googleusercontent.com:443 [vless443 >> direct]
155:101:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.660450 from 46.138.236.102:1251 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
156:102:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.662090 from 213.87.161.52:9782 accepted udp:api.termius.com:443 [vless443 >> direct]
157:103:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.682549 from 213.87.161.52:10607 accepted udp:api.termius.com:443 [vless443 >> direct]
158:104:Jan 26 13:56:57 33701 xray[2170]: 2026/01/26 13:56:57.948996 from 46.138.236.102:1252 accepted udp:www.google.com:443 [vless443 >> direct]
159:105:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.083659 from 46.138.236.102:1253 accepted udp:www.google.com:443 [vless443 >> direct]
160:107:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.178251 from 46.138.236.102:1255 accepted udp:www.google.com:443 [vless443 >> direct]
161:108:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.291191 from 46.138.236.102:1258 accepted udp:www.google.com:443 [vless443 >> direct]
162:109:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.403710 from 46.138.236.102:1259 accepted udp:www.google.com:443 [vless443 >> direct]
163:110:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.522202 from 46.138.236.102:1260 accepted udp:www.google.com:443 [vless443 >> direct]
164:112:Jan 26 13:56:58 33701 xray[2170]: 2026/01/26 13:56:58.813314 from 46.138.236.102:1262 accepted udp:www.google.ru:443 [vless443 >> direct]
165:114:Jan 26 13:56:59 33701 xray[2170]: 2026/01/26 13:56:59.809640 from 46.138.236.102:1264 accepted udp:1.1.1.1:53 [vless443 >> direct]
166:115:Jan 26 13:56:59 33701 xray[2170]: 2026/01/26 13:56:59.816260 from 46.138.236.102:1265 accepted udp:1.1.1.1:53 [vless443 >> direct]
167:116:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.217183 from 46.138.236.102:1267 accepted tcp:chrome.cloudflare-dns.com:443 [vless443 >> direct]
168:117:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.822050 from 46.138.236.102:1271 accepted udp:1.1.1.1:53 [vless443 >> direct]
169:119:Jan 26 13:57:00 33701 xray[2170]: 2026/01/26 13:57:00.880409 from 46.138.236.102:1269 accepted udp:1.1.1.1:53 [vless443 >> direct]
170:121:Jan 26 13:57:01 33701 xray[2170]: 2026/01/26 13:57:01.264956 from 46.138.236.102:1277 accepted tcp:dns.google:443 [vless443 >> direct]
171:122:Jan 26 13:57:01 33701 xray[2170]: 2026/01/26 13:57:01.265021 from 46.138.236.102:1275 accepted tcp:dns.google:443 [vless443 >> direct]
172:127:Jan 26 13:57:03 33701 xray[2170]: 2026/01/26 13:57:03.006690 from 213.87.161.52:19563 accepted udp:chatgpt.com:443 [vless443 >> direct]
173:128:Jan 26 13:57:03 33701 xray[2170]: 2026/01/26 13:57:03.186083 from 213.87.161.52:24248 accepted udp:chatgpt.com:443 [vless443 >> direct]
174:132:Jan 26 13:57:05 33701 xray[2170]: 2026/01/26 13:57:05.087885 from 213.87.161.52:20504 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
175:133:Jan 26 13:57:05 33701 xray[2170]: 2026/01/26 13:57:05.182855 from 213.87.161.52:32293 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
176:140:Jan 26 13:57:08 33701 xray[2170]: 2026/01/26 13:57:08.947353 from 46.138.236.102:2317 accepted udp:rr18---sn-n8v7znlk.googlevideo.com:443 [vless443 >> direct]
177:143:Jan 26 13:57:09 33701 xray[2170]: 2026/01/26 13:57:09.433230 from 46.138.236.102:2319 accepted udp:rr4---sn-n8v7sney.googlevideo.com:443 [vless443 >> direct]
178:145:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.319222 from 46.138.236.102:2323 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
179:147:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.530264 from 46.138.236.102:2325 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
180:148:Jan 26 13:57:10 33701 xray[2170]: 2026/01/26 13:57:10.961836 from 46.138.236.102:2326 accepted udp:googleads.g.doubleclick.net:443 [vless443 >> direct]
181:163:Jan 26 13:57:28 33701 xray[2170]: 2026/01/26 13:57:28.891194 from 46.138.236.102:1270 accepted udp:r1---sn-8ph2xajvh-3w5l.googlevideo.com:443 [vless443 >> direct]
182:165:Jan 26 13:57:29 33701 xray[2170]: 2026/01/26 13:57:29.728811 from 46.138.236.102:1030 accepted udp:ssl.gstatic.com:443 [vless443 >> direct]
183:178:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.365487 from 213.87.161.52:2238 accepted udp:api.termius.com:443 [vless443 >> direct]
184:180:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.373601 from 213.87.161.52:19542 accepted udp:api.termius.com:443 [vless443 >> direct]
185:181:Jan 26 13:57:45 33701 xray[2170]: 2026/01/26 13:57:45.516338 from 213.87.161.52:11445 accepted udp:sentry.io:443 [vless443 >> direct]
186:198:Jan 26 13:58:02 33701 xray[2170]: 2026/01/26 13:58:02.362693 from 213.87.161.52:6936 accepted udp:chatgpt.com:443 [vless443 >> direct]
187:199:Jan 26 13:58:02 33701 xray[2170]: 2026/01/26 13:58:02.518894 from 213.87.161.52:22067 accepted udp:chatgpt.com:443 [vless443 >> direct]
188:219:Jan 26 13:58:15 33701 xray[2170]: 2026/01/26 13:58:15.188569 from 213.87.161.52:5220 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
189:220:Jan 26 13:58:15 33701 xray[2170]: 2026/01/26 13:58:15.477245 from 213.87.161.52:23530 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
190:228:Jan 26 13:58:22 33701 xray[2170]: 2026/01/26 13:58:22.905573 from 213.87.161.52:20137 accepted udp:api.termius.com:443 [vless443 >> direct]
191:229:Jan 26 13:58:23 33701 xray[2170]: 2026/01/26 13:58:23.073586 from 213.87.161.52:7575 accepted udp:api.termius.com:443 [vless443 >> direct]
192:234:Jan 26 13:58:27 33701 xray[2170]: 2026/01/26 13:58:27.016203 from 213.87.161.52:23239 accepted udp:chatgpt.com:443 [vless443 >> direct]
193:236:Jan 26 13:58:27 33701 xray[2170]: 2026/01/26 13:58:27.029028 from 213.87.161.52:31240 accepted udp:chatgpt.com:443 [vless443 >> direct]
194:240:Jan 26 13:58:30 33701 xray[2170]: 2026/01/26 13:58:30.326965 from 213.87.161.52:11358 accepted udp:api.termius.com:443 [vless443 >> direct]
195:243:Jan 26 13:58:30 33701 xray[2170]: 2026/01/26 13:58:30.479075 from 213.87.161.52:28364 accepted udp:api.termius.com:443 [vless443 >> direct]
196:259:Jan 26 13:58:47 33701 xray[2170]: 2026/01/26 13:58:47.278715 from tcp:213.87.161.52:16212 accepted udp:17.253.38.35:123 [vless443 >> direct]
197:264:Jan 26 13:58:53 33701 xray[2170]: 2026/01/26 13:58:53.614821 from 213.87.161.52:2829 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
198:265:Jan 26 13:58:53 33701 xray[2170]: 2026/01/26 13:58:53.682457 from 213.87.161.52:11202 accepted udp:ab.chatgpt.com:443 [vless443 >> direct]
199:276:Jan 26 13:59:02 33701 xray[2170]: 2026/01/26 13:59:02.737911 from 213.87.161.52:28362 accepted udp:api.termius.com:443 [vless443 >> direct]
200:279:Jan 26 13:59:02 33701 xray[2170]: 2026/01/26 13:59:02.907597 from 213.87.161.52:22280 accepted udp:api.termius.com:443 [vless443 >> direct]
201:293:Jan 26 13:59:25 33701 xray[2170]: 2026/01/26 13:59:25.628628 from 213.87.161.52:29914 accepted udp:api.termius.com:443 [vless443 >> direct]
202:294:Jan 26 13:59:25 33701 xray[2170]: 2026/01/26 13:59:25.636892 from 213.87.161.52:16220 accepted udp:api.termius.com:443 [vless443 >> direct]
205:## Routes main (BASELINE, first 200 lines)
209:## Routes main (SNAP2, first 200 lines)
224:ERROR: You need to be root to run this script
234:ERROR: You need to be root to run this script
250:    RX:  bytes packets errors dropped  missed   mcast           
252:    TX:  bytes packets errors dropped carrier collsns           
256:    RX:   bytes   packets errors dropped  missed   mcast           
258:    TX:   bytes   packets errors dropped carrier collsns           
```

## Routing (default routes)
```
211:default via 194.32.142.1 dev enp3s0 proto static 
```

## IP rules (snap2)
```
```
0:	from all lookup local
32766:	from all lookup main
32767:	from all lookup default
```

```

## Firewall DROP / REJECT
```
250:    RX:  bytes packets errors dropped  missed   mcast           
252:    TX:  bytes packets errors dropped carrier collsns           
256:    RX:   bytes   packets errors dropped  missed   mcast           
258:    TX:   bytes   packets errors dropped carrier collsns           
```
