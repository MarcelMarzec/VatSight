---
# Copy this file, rename it to your-guide-slug.md and fill in the fields.
# Files starting with an underscore (like this one) are never published.
# Lines starting with # are comments.

# The page's H1, and the headline in search results unless seo_title is set.
title: How to Do Something on VATSIM
# Optional: a sharper <title> for search results. " | VatSight" is added.
seo_title: How to Do Something on VATSIM (Step by Step)
# 140 to 160 characters for search results and social previews.
# Leave it out and the first paragraph is used instead.
description: A one-sentence promise of what the reader will know or be able to do by the end.
# Optional: shown under the title and on guide cards. Defaults to description.
summary: A slightly friendlier version of the description, one or two sentences.
# Optional: the URL is /guides/<slug>. Defaults to the file name.
slug: how-to-do-something-on-vatsim
# A key from $authors in partials/config.php, or a plain name.
author: marcel-marzec
# Published date. A future date keeps the guide hidden until then.
date: 2026-11-04
# Last meaningful change. Shown as "Updated" and sent to search engines.
updated: 2026-11-04
# Tags group guides on /guides/tag/<tag>. Reuse existing tags where you can.
tags: [VATSIM, ATC]
# Social preview: run `python3 tools/make-og-images.py guides` to make a
# 1200x630 card from the title. og_shot picks the phone screenshot on it
# (a file name from public/images/screenshots, without .webp).
og_shot: uk-overview
# Optional instead: your own wide image (1200x630) for social previews and
# the guide card. When set, no card is generated.
# image: /images/og-image.jpg
# image_alt: Describe what the image shows
# Optional: slugs of guides to suggest at the end, before tag matches.
related: [what-is-vatglasses]
# Optional: set to false to hide the "On this page" contents.
toc: true
# Drafts are only visible on a local dev server (marked "Preview").
draft: true
---
Open with the answer. One or two short paragraphs that tell the reader what this guide covers and why it matters to them. Search engines lift this text for snippets, so make it stand on its own.

## Every H2 becomes an entry in "On this page"

Write in short paragraphs. Use **bold** for UI labels like **Settings → Friends**, `code` for callsigns like `EGLL_TWR`, and [links](/vatsim-map) to the feature pages. Link to another guide by its file name: [What is VATGlasses?](what-is-vatglasses.md).

### H3s are fine for sub-steps

1. Numbered lists for steps.
2. Keep each step to one action.

- Bullet lists for options.
- Nested items need two spaces of indent:
  - like this.

> [!tip] Callouts
> Use `> [!tip]`, `> [!note]`, `> [!info]` or `> [!warning]` for asides. The text after the marker is the title.

| Tables | work | too |
| --- | --- | --- |
| Keep them | narrow | for phones |

Phone screenshots shrink to a sensible size automatically. The text in quotes becomes the caption:

![VatSight map showing merged ATC sectors over the Netherlands](/images/screenshots/merged-sectors-750.webp "Merged sectors over the Netherlands and Belgium")

## End with a next step

Point the reader at the most relevant feature page or guide. The page adds the author box, related guides and an App Store panel automatically.
