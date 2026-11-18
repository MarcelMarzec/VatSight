---
title: VATSIM ATC Positions Explained: DEL, GND, TWR, APP and CTR
seo_title: VATSIM ATC Positions: DEL, GND, TWR, APP & CTR
description: What VATSIM's ATC callsigns mean, what each position does from Delivery to Centre, how top-down coverage works, and which controller to call next.
summary: What every VATSIM ATC callsign means, what each position does, and how to work out who to call when half of them are offline.
author: marcel-marzec
og_shot: atc-details
date: 2026-11-04
tags: [ATC, VATSIM, Pilots]
related: [what-is-vatglasses, track-friends-on-vatsim]
---
**VATSIM air traffic control is split into positions that mirror the real world: Delivery, Ground, Tower, Approach and Centre, plus ATIS and a few specials.** Each one is a callsign ending in a short suffix like `_TWR` or `_CTR`. Once you can read those suffixes, a VATSIM map tells you exactly who is online, what they do, and who you should be talking to.

## How a VATSIM ATC callsign is built

A controller’s callsign has two or three parts, separated by underscores:

- **The prefix**, usually the airport’s ICAO code (`EGLL` for London Heathrow) or a code for the wider area (`EGTT` for London’s area control centre).
- **An optional middle part** for split positions, such as `EGLL_N_APP` and `EGLL_S_APP` for two approach sectors, or `EGTT_W_CTR` for one slice of London Control. Some divisions also use a middle letter for training or mentoring sessions.
- **The suffix**, which says what kind of position it is. That’s the part that matters most.

So `EDDF_TWR` is Frankfurt Tower, and `EGTT_W_CTR` is a western sector of London Control.

## The positions, from the ground up

| Suffix | Position | What they do for you |
| --- | --- | --- |
| `_DEL` | Delivery | Your IFR clearance: route, initial climb and squawk, before you push |
| `_GND` | Ground | Pushback, start-up and taxi to and from the runway |
| `_TWR` | Tower | The runway: line-up, take-off and landing clearances, and traffic close to the airport |
| `_ATIS` | ATIS | Not a person. A recorded broadcast with the runway in use, weather and the current information letter |
| `_APP` / `_DEP` | Approach / Departure | Radar control around busy airports: climbing you out, sequencing and vectoring arrivals |
| `_CTR` | Centre (Control) | En-route radar control over a large area, often called “Control” or “Radar” on the radio |
| `_FSS` | Flight Service | Very large areas, such as oceanic airspace, usually without a radar service |
| `_OBS` | Observer | Connected to watch and listen, not controlling anything |

Big airports split these further. A busy hub might run two Ground positions, separate Departure and Approach, and several Centre sectors stacked on top of each other.

## Top-down coverage: when positions are offline

VATSIM is run by volunteers, so most of the time not every position is staffed. The rule that makes this work is **top-down coverage**: when a position is offline, the next position above it provides its service, unless local procedures say otherwise.

- At an airport with only **Tower** online, Tower usually gives your clearance and taxi as well.
- With only **Approach** online, Approach usually covers Tower, Ground and Delivery at the airports beneath it.
- With only **Centre** online, Centre covers everything below it that isn’t staffed.

Which airports and sectors fall to which controller depends on the local setup, and that’s exactly what [VATGlasses](what-is-vatglasses.md) maps out. It lists, for every sector and airport, the order in which positions take it over.

> [!tip] A quick rule for pilots
> On departure, work up the list: ATIS, then Delivery, Ground, Tower, Departure and Centre, skipping anyone who’s offline. On arrival, work back down. Always contact the lowest position that’s online and covers you.

## Controller ratings

Every VATSIM controller has a rating, and the rating limits which positions they can staff. You’ll see it next to their name on most VATSIM maps:

| Rating | Name | Usually staffs |
| --- | --- | --- |
| S1 | Tower Trainee | Delivery and Ground |
| S2 | Tower Controller | Tower |
| S3 | Senior Student | Approach and Departure |
| C1 | Enroute Controller | Centre |
| C3 | Senior Controller | Centre, plus experience beyond C1 |
| I1, I3 | Instructor, Senior Instructor | Any position, and they train others |
| SUP, ADM | Supervisor, Administrator | Network staff who look after the network as a whole |

Exactly what each rating may staff is set by each division, and many airports need extra endorsements on top of the rating. Students in training can also staff positions above their rating while a mentor watches.

## Seeing who’s online on your iPhone

[VatSight](/vatsim-tracker) makes this visible at a glance:

- **Airport badges** on the map show which services are open: **T** for Tower, **G** for Ground, **D** for Delivery and **A** for ATIS.
- **Sector labels** show every online Approach and Centre controller over the exact airspace they own, using VATGlasses data.
- **Tap an airport** to list every controller providing a service there, from Delivery up to the Centre controller covering it top-down, along with the ATIS and the latest METAR.
- **Tap a sector or controller** for their rating, frequency, logon time and controller info.
- **Search ATC** by callsign, name or frequency, and filter by facility.

![VatSight ATC details for a VATSIM approach controller, showing frequency, rating, facility and sector info](/images/screenshots/atc-details-750.webp "Tap any sector for the controller behind it")

Now you know who’s who, read [What is VATGlasses?](what-is-vatglasses.md) to see how the map works out who owns which piece of sky.
