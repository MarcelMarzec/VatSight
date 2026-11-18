---
title: What Is VATGlasses? VATSIM’s Live ATC Sector Map Explained
seo_title: What Is VATGlasses? VATSIM ATC Sectors Explained
description: VATGlasses is the community map of VATSIM airspace showing which controller owns which sector. What it is, how it works and where to use it.
summary: The community-built map that shows exactly which VATSIM controller owns which piece of airspace, and why callsigns alone can’t tell you that.
author: marcel-marzec
og_shot: blended-sectors
date: 2026-11-04
tags: [VATGlasses, VATSIM, ATC]
related: [vatsim-atc-positions-explained]
---
**VATGlasses is an open, community-maintained map of VATSIM airspace.** It describes every ATC sector’s shape and vertical limits, which controller positions can own each sector, and who takes over when a position is offline. Put that next to live VATSIM data and you can see, at any moment, exactly which controller is responsible for any point in the sky.

It started as a website, [vatglasses.uk](https://vatglasses.uk), but the data behind it is open, which is why apps like [VatSight](/vatglasses) can show the same sectors on an iPhone.

## Why callsigns alone aren’t enough

Every VATSIM controller connects with a callsign like `EDDF_TWR` or `EGTT_W_CTR`. The first part tells you roughly where they are, and the last part tells you what kind of position it is. What it doesn’t tell you is:

- **Exactly which airspace they own.** Busy areas are split into many sectors, and a single controller might be working one of them or a dozen.
- **From what level to what level.** Airspace is stacked vertically, so the controller above an airport at FL100 can be a different person from the one at FL350.
- **What happens when someone logs off.** On VATSIM, when a position is offline the next position up usually covers it, known as top-down coverage. Who that is depends on local rules.

Many VATSIM maps answer this with one big shape per region, usually the FIR boundary, which is fine for a centre controller working everything alone but wrong as soon as the airspace is split. VATGlasses fills in the detail.

## What’s in the VATGlasses data

The data lives in a public GitHub repository, [lennycolton/vatglasses-data](https://github.com/lennycolton/vatglasses-data), with files for each region. Volunteers from each vACC maintain their own area. Each region describes three things:

| Part | What it holds |
| --- | --- |
| **Positions** | Each ATC position’s callsign prefixes, its type (`TWR`, `APP`, `CTR` and so on), usually its frequency, and a colour |
| **Sectors** | The shape of each piece of airspace, its lower and upper level, and an ordered list of the positions that can own it |
| **Airports** | Which positions provide top-down service to each airport |

The data is published under the Creative Commons BY-NC-SA 4.0 licence, so other non-commercial projects can use it as long as they credit it and share alike.

## How sector ownership works

The ordered owner list is the clever part. Picture a sector near a busy airport whose list reads, in order: the approach controller, then the area controller for that part of the country, then the centre controller who covers the whole FIR.

- If **approach** is online, the sector is theirs.
- If approach logs off but the **area** controller is on, it moves to them.
- If only the **centre** controller is online, they own it, along with everything else that falls through to them.

A VATGlasses-aware map walks down that list every time the network updates and colours the sector by whoever is first in line and online. When a controller logs on or off, the sectors redraw themselves to match.

> [!tip] Who should I call?
> As a pilot, the sector you’re in tells you which controller to contact, and that’s exactly what VATGlasses shows. Our guide to [VATSIM ATC positions](vatsim-atc-positions-explained.md) explains top-down coverage from the pilot’s side.

## VATGlasses vs VATSpy data

If you’ve used VATSIM tools for a while you’ll also have met the **VATSpy data project**, which defines FIR boundaries, airports and the callsign prefixes that go with them. Many VATSIM maps use it to draw one outline per FIR.

The two complement each other. VATSpy data says *which FIR* a centre controller belongs to; VATGlasses says *which part of it* each controller owns, from which level, and in what order. Coverage differs by region: some vACCs have detailed VATGlasses data down to individual approach sectors, while others only describe the basics.

## Where can you use VATGlasses?

- **In a browser** at [vatglasses.uk](https://vatglasses.uk), the original VATGlasses website.
- **On iPhone and iPad** with [VatSight](/vatglasses), which downloads the VATGlasses data once, keeps it on your phone, and matches it against live VATSIM traffic every 15 seconds. You can merge each controller’s sectors into one outline, filter them by altitude, and tap any sector for the controller behind it.

![VatSight on iPhone showing merged VATGlasses sectors over the Netherlands and Belgium, one outline per controller](/images/screenshots/merged-sectors-750.webp "VATGlasses sectors in VatSight, merged into one outline per controller")

## Common questions

### Is VATGlasses an official VATSIM product?

No. VATGlasses is a community project, and its data is maintained by volunteers across the network’s vACCs. VatSight is an independent app that uses that data; it isn’t made by the VATGlasses team either.

### Why does a controller show up with no sector?

Usually because their position isn’t in VATGlasses yet, or their callsign or frequency doesn’t match the data, which happens with one-off event positions. VatSight still draws a small circle around the airport for approach controllers it can’t match, and lists everyone else under **Settings → Sector Maintainers** so data maintainers can spot the gap.

### How do I fix wrong sector data?

Corrections go to the vACC that maintains that region, usually through a pull request or issue on the [vatglasses-data repository](https://github.com/lennycolton/vatglasses-data). If you maintain a region yourself, VatSight can load your fork so you can test changes on live traffic before they’re merged; the [VATGlasses page](/vatglasses#faq) explains how.
