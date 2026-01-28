# Observed Snapshot v4 — uuid fix applied

UTC: 2026-01-27T14:46:59Z
HOST: 33701

## runtime env file present
-rw------- 1 root root 198 Jan 27 14:25 /etc/vps-tier/runtime.env

## trial uuid presence in applied xray config (first8 only)
TRIAL_FIRST8=<NOT_SET>

## xray status (first 25 lines)
● xray.service - Xray Service
     Loaded: loaded (/etc/systemd/system/xray.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/xray.service.d
             └─10-donot_touch_single_conf.conf
     Active: active (running) since Tue 2026-01-27 14:43:36 UTC; 3min 23s ago
       Docs: https://github.com/xtls
   Main PID: 774638 (xray)
      Tasks: 9 (limit: 2217)
     Memory: 9.2M
        CPU: 13.033s
     CGroup: /system.slice/xray.service
             └─774638 /usr/local/bin/xray run -config /usr/local/etc/xray/config.json

Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.837289 from 46.138.236.102:2317 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.838252 from 46.138.236.102:2318 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.838580 from 46.138.236.102:2309 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.839243 from 46.138.236.102:1253 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.864539 from 46.138.236.102:1274 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:58 33701 xray[774638]: 2026/01/27 14:46:58.247006 from 46.138.236.102:2328 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:58 33701 xray[774638]: 2026/01/27 14:46:58.851808 from 46.138.236.102:2336 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:59 33701 xray[774638]: 2026/01/27 14:46:59.023931 from 46.138.236.102:2340 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:59 33701 xray[774638]: 2026/01/27 14:46:59.025538 from 213.87.161.223:15751 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:59 33701 xray[774638]: 2026/01/27 14:46:59.026783 from 213.87.161.223:11976 rejected  proxy/vless/encoding: invalid request user id

## xray journal tail (120) uuid redacted
Jan 27 14:46:40 33701 xray[774638]: 2026/01/27 14:46:40.808206 from 46.138.236.102:1065 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.800794 from 46.138.236.102:1070 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.835237 from 213.87.161.126:4178 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.893676 from 46.138.236.102:1218 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.917502 from 46.138.236.102:1251 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.918648 from 46.138.236.102:1087 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.919492 from 46.138.236.102:1232 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.919862 from 46.138.236.102:1084 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.948196 from 46.138.236.102:1245 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.949015 from 46.138.236.102:1257 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.952801 from 46.138.236.102:1225 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:41 33701 xray[774638]: 2026/01/27 14:46:41.957558 from 46.138.236.102:1243 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:42 33701 xray[774638]: 2026/01/27 14:46:42.008207 from 46.138.236.102:1244 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:42 33701 xray[774638]: 2026/01/27 14:46:42.008263 from 46.138.236.102:1217 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:42 33701 xray[774638]: 2026/01/27 14:46:42.008276 from 46.138.236.102:1231 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:42 33701 xray[774638]: 2026/01/27 14:46:42.008288 from 46.138.236.102:1224 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:42 33701 xray[774638]: 2026/01/27 14:46:42.008298 from 46.138.236.102:1247 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:42 33701 xray[774638]: 2026/01/27 14:46:42.067314 from 46.138.236.102:1072 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:43 33701 xray[774638]: 2026/01/27 14:46:43.151336 from 46.138.236.102:1216 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:43 33701 xray[774638]: 2026/01/27 14:46:43.297626 from 46.138.236.102:1027 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:43 33701 xray[774638]: 2026/01/27 14:46:43.305278 from 46.138.236.102:1068 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:43 33701 xray[774638]: 2026/01/27 14:46:43.458563 from 46.138.236.102:2327 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:43 33701 xray[774638]: 2026/01/27 14:46:43.466607 from 46.138.236.102:2330 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:43 33701 xray[774638]: 2026/01/27 14:46:43.688577 from 46.138.236.102:2341 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:44 33701 xray[774638]: 2026/01/27 14:46:44.804037 from 46.138.236.102:2362 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:45 33701 xray[774638]: 2026/01/27 14:46:45.000985 from 46.138.236.102:1055 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:45 33701 xray[774638]: 2026/01/27 14:46:45.437540 from 46.138.236.102:1058 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.883005 from 46.138.236.102:1252 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.894272 from 46.138.236.102:1219 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.898046 from 46.138.236.102:1082 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.900844 from 46.138.236.102:1260 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.911327 from 46.138.236.102:1026 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.916378 from 46.138.236.102:1235 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.917329 from 46.138.236.102:1248 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.917356 from 46.138.236.102:2308 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.925499 from 46.138.236.102:1242 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.927977 from 46.138.236.102:1044 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.930839 from 46.138.236.102:2306 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.933072 from 46.138.236.102:1222 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.953916 from 46.138.236.102:1263 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.960690 from 46.138.236.102:1236 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:47 33701 xray[774638]: 2026/01/27 14:46:47.986973 from 46.138.236.102:1228 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.042126 from 46.138.236.102:2310 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.116806 from 213.87.161.126:22465 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.193665 from 46.138.236.102:2312 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.438587 from 46.138.236.102:2313 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.842887 from 213.87.161.223:8608 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.889620 from 46.138.236.102:2454 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.901124 from 46.138.236.102:2458 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.930531 from 46.138.236.102:2486 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:48 33701 xray[774638]: 2026/01/27 14:46:48.957201 from 46.138.236.102:2449 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:49 33701 xray[774638]: 2026/01/27 14:46:49.221568 from 46.138.236.102:2495 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:49 33701 xray[774638]: 2026/01/27 14:46:49.223023 from 46.138.236.102:2754 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:49 33701 xray[774638]: 2026/01/27 14:46:49.229221 from 46.138.236.102:2753 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:49 33701 xray[774638]: 2026/01/27 14:46:49.908626 from 46.138.236.102:2757 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:49 33701 xray[774638]: 2026/01/27 14:46:49.930917 from 46.138.236.102:2761 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:50 33701 xray[774638]: 2026/01/27 14:46:50.690174 from 213.87.161.223:12335 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:51 33701 xray[774638]: 2026/01/27 14:46:51.877527 from 46.138.236.102:2765 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:52 33701 xray[774638]: 2026/01/27 14:46:52.306830 from 46.138.236.102:2763 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:52 33701 xray[774638]: 2026/01/27 14:46:52.700446 from 213.87.161.223:33007 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:52 33701 xray[774638]: 2026/01/27 14:46:52.704416 from 46.138.236.102:2769 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:52 33701 xray[774638]: 2026/01/27 14:46:52.714406 from 46.138.236.102:2768 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.170648 from 46.138.236.102:2771 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.231029 from 46.138.236.102:2772 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.313772 from 46.138.236.102:2773 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.774000 from 46.138.236.102:2774 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.889881 from 46.138.236.102:2785 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.890755 from 46.138.236.102:2783 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.893583 from 46.138.236.102:2781 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.894294 from 46.138.236.102:2790 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.900516 from 46.138.236.102:2778 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.902199 from 46.138.236.102:2775 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.907092 from 46.138.236.102:2789 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.919789 from 46.138.236.102:2777 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.920842 from 46.138.236.102:2800 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.931565 from 46.138.236.102:2797 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.941750 from 46.138.236.102:2796 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.960599 from 46.138.236.102:2799 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.960957 from 46.138.236.102:2782 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.960993 from 46.138.236.102:2784 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:53 33701 xray[774638]: 2026/01/27 14:46:53.961140 from 46.138.236.102:2794 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:54 33701 xray[774638]: 2026/01/27 14:46:54.605491 from 46.138.236.102:2802 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:54 33701 xray[774638]: 2026/01/27 14:46:54.642986 from 46.138.236.102:2803 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:54 33701 xray[774638]: 2026/01/27 14:46:54.732624 from 213.87.161.223:23397 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:55 33701 xray[774638]: 2026/01/27 14:46:55.162435 from 46.138.236.102:2810 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:55 33701 xray[774638]: 2026/01/27 14:46:55.184456 from 46.138.236.102:2813 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:55 33701 xray[774638]: 2026/01/27 14:46:55.254442 from 46.138.236.102:2811 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:55 33701 xray[774638]: 2026/01/27 14:46:55.257665 from 46.138.236.102:2812 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:56 33701 xray[774638]: 2026/01/27 14:46:56.026232 from 46.138.236.102:1045 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:56 33701 xray[774638]: 2026/01/27 14:46:56.291481 from 46.138.236.102:1046 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:56 33701 xray[774638]: 2026/01/27 14:46:56.584779 from 46.138.236.102:1047 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.426259 from 46.138.236.102:1069 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.653527 from 46.138.236.102:1033 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.733488 from 46.138.236.102:1085 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.818673 from 46.138.236.102:1255 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.820283 from 46.138.236.102:1264 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.821113 from 46.138.236.102:2325 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.821552 from 46.138.236.102:2321 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.822302 from 46.138.236.102:1230 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.822936 from 46.138.236.102:2324 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.824008 from 46.138.236.102:1249 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.824362 from 46.138.236.102:2326 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.826520 from 46.138.236.102:2322 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.832943 from 46.138.236.102:2323 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.834611 from 46.138.236.102:1234 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.834645 from 46.138.236.102:1269 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.835022 from 46.138.236.102:2315 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.835991 from 46.138.236.102:1275 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.836393 from 46.138.236.102:1270 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.836435 from 46.138.236.102:2320 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.837289 from 46.138.236.102:2317 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.838252 from 46.138.236.102:2318 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.838580 from 46.138.236.102:2309 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.839243 from 46.138.236.102:1253 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:57 33701 xray[774638]: 2026/01/27 14:46:57.864539 from 46.138.236.102:1274 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:58 33701 xray[774638]: 2026/01/27 14:46:58.247006 from 46.138.236.102:2328 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:58 33701 xray[774638]: 2026/01/27 14:46:58.851808 from 46.138.236.102:2336 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:59 33701 xray[774638]: 2026/01/27 14:46:59.023931 from 46.138.236.102:2340 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:59 33701 xray[774638]: 2026/01/27 14:46:59.025538 from 213.87.161.223:15751 rejected  proxy/vless/encoding: invalid request user id
Jan 27 14:46:59 33701 xray[774638]: 2026/01/27 14:46:59.026783 from 213.87.161.223:11976 rejected  proxy/vless/encoding: invalid request user id
