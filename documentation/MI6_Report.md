# 🕵️ MI6 DEEP DIVE JELENTÉS: Bróker Adatgyűjtési Taktikák

**Dátum:** 2026.02.21
**Elemzett Forrás:** MI6 Knowledge Base (889 találat)

## 1. Összefoglaló (Executive Summary)
A bróker (MetaQuotes) nem csupán kereskedési adatokat, hanem **teljes hardveres és szoftveres ujjlenyomatot** (fingerprint) is gyűjt a kliensről. Az elemzés megerősíti a 'Hybrid Monster' elméletet: a natív C++ alkalmazás webes technológiákat (WebView) használ a megfigyelésre.

## 2. Észlelt Adatgyűjtési Kategóriák

### 🛡️ Browser Fingerprinting (329 találat)
| Fájl | Kulcsszavak | Részlet |
|---|---|---|
| `amiunique-master/LICENSE.md` | amiunique | `the mit license (mit)  copyright (c) 2014 pierre laperdrix  permission is hereby granted, free of ch...` |
| `amiunique-master/dissemination.md` | amiunique | `# award * [cnil award](https://www.cnil.fr/fr/la-cnil-et-inria-decernent-le-prix-protection-de-la-vi...` |
| `amiunique-master/fpDB.sql` | amiunique, canvas, webgl, timezone, font | `-- phpmyadmin sql dump -- version 4.4.11 -- http://www.phpmyadmin.net -- -- host: localhost -- gener...` |
| `amiunique-master/extensionData.sql` | amiunique, canvas, webgl, timezone, font | `-- phpmyadmin sql dump -- version 4.5.4.1deb2ubuntu2 -- http://www.phpmyadmin.net -- -- client :  lo...` |
| `amiunique-master/README.md` | amiunique | `# am i unique ? #  this repository contains all the source code from the [amiunique.org](https://ami...` |
| `amiunique-master/combinationStats.sql` | amiunique | `-- phpmyadmin sql dump -- version 4.4.11 -- http://www.phpmyadmin.net -- -- host: localhost -- gener...` |
| `amiunique-master/audio.sql` | amiunique | `-- phpmyadmin sql dump -- version 4.6.2 -- https://www.phpmyadmin.net/ -- -- host: localhost -- gene...` |
| `amiunique-master/website/activator.bat` | amiunique | `@rem activator launcher script @rem @rem environment: @rem in order for activator to work you must h...` |
| `amiunique-master/website/test/IntegrationTest.java` | amiunique | `import org.junit.*;  import play.mvc.*; import play.test.*; import play.libs.f.*;  import static pla...` |
| `amiunique-master/website/test/ApplicationTest.java` | amiunique | `import java.util.arraylist; import java.util.hashmap; import java.util.list; import java.util.map;  ...` |

### 🛡️ Telemetry & Analytics (75 találat)
| Fájl | Kulcsszavak | Részlet |
|---|---|---|
| `amiunique-master/website/public/javascripts/hello.js` | amiunique | `if (window.console) {   console.log("welcome to your play application's javascript!"); }...` |
| `amiunique-master/website/app/Global.java` | amiunique | `import play.logger; import play.libs.akka; import scala.concurrent.duration.duration; import akka.ac...` |
| `amiunique-master/website/app/models/AudioEntity.java` | amiunique | `package models;  import javax.persistence.basic; import javax.persistence.entity; import javax.persi...` |
| `amiunique-master/website/app/models/FpDataEntity.java` | amiunique, canvas, webgl, timezone, font | `package models;  import javax.persistence.*; import java.sql.timestamp; import java.util.hashmap;  @...` |
| `fingerprintjs-master/readme.md` | fingerprintjs | `<p align="center">   <a href="https://fingerprint.com">     <picture>       <source media="(prefers-...` |
| `hosts-master/data/add.2o7Net/update.json` | tracking | `{   "name": "add.2o7net",   "description": "2o7net tracking sites based on [hostsfile.org](https://w...` |
| `hosts-master/data/yoyo.org/update.json` | tracking | `{   "name": "yoyo.org",   "description": "blocking with ad server and tracking server hostnames.",  ...` |
| `mitmproxy-main/CHANGELOG.md` | user-agent, timezone, font | `# release history  <!-- ✨ please add a bullet point describing your change.                         ...` |
| `mitmproxy-main/examples/contrib/webscanner_helper/urlinjection.py` | user-agent | `import abc import html import json import logging  from mitmproxy import flowfilter from mitmproxy.h...` |
| `mitmproxy-main/mitmproxy/tools/web/templates/login.html` | font | `<!doctype html> <html lang="en"> <head>     <meta charset="utf-8">     <title>mitmproxy</title>     ...` |

### 🛡️ User Identification (2 találat)
| Fájl | Kulcsszavak | Részlet |
|---|---|---|
| `mitmproxy-main/mitmproxy/net/http/user_agents.py` | user-agent | `""" a small collection of useful user-agent header strings. these should be kept reasonably current ...` |
| `mitmproxy-main/docs/bucketassets/robots.txt` | user-agent | `user-agent: * disallow: /archive/ disallow: /master/ disallow: /dev/ ...` |

### 🛡️ Network Surveillance (6 találat)
| Fájl | Kulcsszavak | Részlet |
|---|---|---|
| `fingerprintjs-master/src/utils/data.ts` | fingerprintjs | `/*  * this file contains functions to work with pure data only (no browser features, dom, side effec...` |
| `mitmproxy-main/mitmproxy/tools/console/commander/commander.py` | canvas | `import abc from collections.abc import sequence from typing import namedtuple  import urwid from urw...` |
| `mitmproxy-main/mitmproxy/utils/strutils.py` | font | `import codecs import io import re from collections.abc import iterable from typing import overload  ...` |
| `wireshark-master/resources/protocols/diameter/Travelping.xml` | timezone | `<?xml version="1.0" encoding="utf-8"?>  <!-- travelping vendor-specific avps. -->  <vendor vendor-id...` |
| `wireshark-master/tools/make-midi-sysex.py` | user-agent | `#!/usr/bin/env python3 # # generate epan/dissectors/packet-midi-sysex-id.c and # epan/dissectors/pac...` |
| `wireshark-master/wiretap/pcapng.c` | timezone | `/* pcapng.c  *  * wiretap library  * copyright (c) 1998 by gilbert ramirez <gram@alumni.rice.edu>  *...` |

## 3. Azonosított Telemetria Domainek (Blokkolandó)
A következő domainekre irányuló forgalom gyanús adatküldést jelez:
- `fonts.googleapis.com`
- `code.google.com`
- `sites.google.com`

## 4. Következtetés és Védelem
A `mitm_filter.py` szkript frissítve lett ezekkel a domainekkel. A védekezés kulcsa a hálózati forgalom szűrése (MITM) és a hardveres jellemzők (Canvas, WebGL) zajosítása.
