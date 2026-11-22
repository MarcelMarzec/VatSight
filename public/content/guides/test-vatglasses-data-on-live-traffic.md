---
title: How to Test VATGlasses Data on Live VATSIM Traffic
seo_title: Test VATGlasses Sector Data on Live VATSIM Traffic
description: A guide for vACC sector maintainers load your VATGlasses fork in VatSight, check it against live controllers, find unmatched positions and simulate logons.
summary: Load your own fork of the VATGlasses data, see it against real controllers on the network, and catch missing positions and broken files before your pull request is merged.
slug: test-vatglasses-data-on-live-traffic
author: marcel-marzec
date: 2026-11-21
updated: 2026-11-21
tags:
  - VATGlasses
  - ATC
  - VatSight
og_shot: show-inactive-sectors
related:
  - what-is-vatglasses
  - vatsim-atc-positions-explained
toc: true
draft: false
---
**If you maintain VATGlasses data for your vACC, VatSight can load your own fork of the data and show it against live VATSIM traffic on your iPhone.** You can see which online controllers your data doesn't match yet, catch files that fail to load, and simulate any position logging on to check that sectors hand over the way your local procedures say they should, all before your changes are merged.

Everything in this guide lives under **Settings → Sector Maintainers** in [VatSight](/vatglasses). It's free, there's no account, and nothing you test is sent anywhere: a custom data source only changes what your own device shows.

> [!note] New to VATGlasses?
> This guide assumes you already know how the data is structured. If not, start with [What is VATGlasses?](what-is-vatglasses.md), which covers positions, sectors and how ownership works.

## What VatSight gives a data maintainer

| Tool | What it's for |
| --- | --- |
| **Custom data source** | Load a public fork of vatglasses-data instead of the official repository |
| **Unmatched controllers** | Every online controller VatSight couldn't place in a sector |
| **Synthetic sectors** | Approach and departure controllers drawn as a fallback circle because no sector matched |
| **Parse errors** | Any file or folder in the dataset that failed to decode, and why |
| **Invalid airport coordinates** | Airports whose latitude or longitude is out of range after parsing |
| **Debug panel** | Simulate any position in the data logging on, without anyone connecting |
| **Sector details** | Tap a sector for its ID, group, altitude band and full ownership list |

## Step 1: Turn on developer mode

1. Open **Settings → Sector Maintainers**.
2. Turn on **Developer Mode**.

The maintainer tools appear underneath, and a small **debug** button (the ant icon) appears in the top-left corner of the map. Turn developer mode off and VatSight goes back to the official data straight away.

## Step 2: Load your fork of the data

VatSight downloads the VATGlasses data straight from GitHub, so it can load any fork that has the same layout as [lennycolton/vatglasses-data](https://github.com/lennycolton/vatglasses-data).

1. Push your changes to your fork. VatSight reads the **`main` branch**, so test on `main` or merge your work branch into it first.
2. Make sure the repository is **public**. VatSight doesn't sign in to GitHub, so it can't see private repositories.
3. In **Settings → Sector Maintainers**, enter the repository as `owner/repo` under **Vatglasses Data Source**, for example `your-github-name/vatglasses-data`.
4. Tap **Apply**. VatSight clears its cached copy and downloads your fork.

To check it loaded, open **Settings → VATGlasses Data**. A **Custom Repository Active** banner names the repository in use, along with the number of sectors, positions and airports it contains. If those numbers look wrong for what you changed, check the parse errors (step 4).

### Loading new commits

VatSight normally checks GitHub for new data at most once a week, which suits everyone else but is too slow when you're iterating. After you push a change, go to **Settings → VATGlasses Data** and tap **Redownload Vatglasses Sectors** to fetch the latest commit right away.

> [!warning] GitHub rate limits
> Downloads go through GitHub's public API, which allows around 60 unauthenticated requests an hour from one network. If you redownload many times in a row and nothing changes, wait a few minutes and try again.

When you're done, tap **Reset to Default** to go back to the official repository.

## Step 3: Check your data against live controllers

Open the map in your region while controllers are online. On every refresh (every 15 seconds by default) VatSight matches each controller to a VATGlasses position by callsign prefix and frequency, then colours the sectors that position owns. Anyone it can't place shows up in **Settings → Sector Maintainers**.

### Unmatched controllers

This list shows every online controller that didn't match a position in the loaded data, with their callsign, frequency, CID and name. The usual causes are:

- **A callsign prefix that isn't listed** for the position, for example a new split like `EGTT_E_CTR` that was added locally but not to the data.
- **A frequency that doesn't match** the one in the data, often after a real-world frequency change.
- **A one-off event position** that was never meant to be in the dataset.

Ground, delivery, supervisor and observer connections rarely own airspace, so they're hidden by default. Tap the pills at the top (**OBS Freq**, **_GND**, **_DEL**, **_SUP**, **_OBS**) to include them.

### Synthetic sectors

When an `_APP` or `_DEP` controller can't be matched but their airport is known, VatSight still draws a small circle around the airport so pilots can see the airport is covered. These are listed in yellow at the top of the list. Tap one to jump to it on the map. A synthetic sector in your region usually means an approach position is missing from your data or its frequency is out of date.

When both lists are empty, VatSight shows **All controllers matched**.

## Step 4: Fix parse errors and invalid airports

Below the controllers are two more checks that come from the last data download:

- **Parse Errors** lists each file or folder that failed to decode, with the error message. A missing key or a typo in a JSON file shows up here, and whatever that file describes won't appear on the map until it's fixed.
- **Invalid Airport Coordinates** lists airports whose latitude or longitude falls outside valid ranges after parsing. These would draw in the wrong place, or not at all, so it's worth checking for swapped values or a missing minus sign.

## Step 5: Simulate controllers with the debug panel

You don't have to wait for the right people to log on. Tap the **debug** button on the map to open the debug panel, which lists every position in the loaded data.

- **Filter by type** with the chips at the top (`DEL`, `GND`, `TWR`, `APP`, `CTR`, `FSS`).
- **Search** by position name, ID or callsign prefix.
- **Tap a position** to add a simulated controller on its callsign and frequency. The map redraws as if they had just connected.
- **Remove** one from the **Active** list at the top, or tap the position again.

Simulated controllers only exist on your device and disappear when the app closes.

### Testing top-down coverage

The debug panel is the quickest way to check an ownership hierarchy:

1. Add only the centre position for your area. Every sector it can own should take its colour.
2. Add an approach position. Its sectors should move from the centre to the approach controller.
3. Add the tower. The lowest sectors around the airport should move again.
4. Remove them in a different order and check that coverage falls back the way your procedures expect.

Turn on **Inactive sectors** from the layers button to see the whole airspace, including sectors nobody owns, and **Merge sectors** to see each controller's airspace as one outline. Use the altitude filter to check sector floors and ceilings level by level.

## Inspect a single sector

Tap any sector on the map to see its details:

- **Sector ID** and **FIR / Group**, so you can find it in the data files.
- **Altitude Band**, the combined vertical limits of the active controller's airspace.
- **Ownership Hierarchy**, the ordered list of positions that can own the sector, with online ones highlighted and offline ones folded away.

If the owner is wrong, the hierarchy shows you which position VatSight found first and online, which usually points straight at the line to fix.

## A workflow before you open a pull request

1. Push your changes to `main` on your public fork.
2. Apply the fork in VatSight, or redownload if it's already applied.
3. Confirm **Parse Errors** and **Invalid Airport Coordinates** are empty.
4. Use the debug panel to walk through your top-down coverage.
5. Check the **Unmatched Controllers** list during a busy evening or an event in your region.
6. Open your pull request on [vatglasses-data](https://github.com/lennycolton/vatglasses-data), then **Reset to Default** once it's merged.

## Common questions

### Does testing my fork affect anyone else?

No. The custom data source is a setting on your device. Everyone else keeps seeing the official VATGlasses data until your changes are merged upstream.

### Can I test a branch other than main?

Not at the moment: VatSight always loads the `main` branch of the repository you enter. A separate fork, or a fork whose `main` you reset after testing, works well.

### My region still looks wrong after I pushed a fix

Redownload from **Settings → VATGlasses Data**, then check **Parse Errors**. If the counts didn't change, GitHub may be rate limiting you, or the commit may not be on `main` yet.

### Who do I ask about the data format?

Questions about the format belong with the VATGlasses team on their repository. If something looks like a VatSight bug, for example data that works on [vatglasses.uk](https://vatglasses.uk) but draws differently in the app, [get in touch](/contact) or open an issue on VatSight's GitHub.
