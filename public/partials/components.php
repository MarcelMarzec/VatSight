<?php
defined('SITE') or exit;
// Reusable markup: icons, the App Store badge, phone screenshots, FAQ lists,
// breadcrumbs and the closing download panel. Everything returns a string.

function icon(string $name): string
{
    $stroke = 'viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"';
    return match ($name) {
        'github'   => '<svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2C6.48 2 2 6.58 2 12.25c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.48v-1.7c-2.78.62-3.37-1.36-3.37-1.36-.46-1.2-1.11-1.52-1.11-1.52-.91-.64.07-.63.07-.63 1 .07 1.53 1.05 1.53 1.05.9 1.57 2.36 1.11 2.93.85.09-.67.35-1.11.64-1.37-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.05a9.3 9.3 0 0 1 5 0c1.9-1.33 2.74-1.05 2.74-1.05.55 1.42.2 2.47.1 2.73.64.72 1.03 1.63 1.03 2.75 0 3.93-2.34 4.79-4.57 5.05.36.32.68.94.68 1.9v2.82c0 .27.18.58.69.48A10.26 10.26 0 0 0 22 12.25C22 6.58 17.52 2 12 2Z"/></svg>',
        'radar'    => '<svg ' . $stroke . '><path d="M12 12V4"/><path d="M4 12a8 8 0 1 0 16 0 8 8 0 1 0-16 0Z" opacity="0.45"/><circle cx="12" cy="12" r="1.3" fill="currentColor" stroke="none"/></svg>',
        'layers'   => '<svg ' . $stroke . '><polygon points="12 3 21 8 12 13 3 8"/><polyline points="3 13 12 18 21 13"/><polyline points="3 17.5 12 22 21 17.5"/></svg>',
        'card'     => '<svg ' . $stroke . '><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M7 9.5h5M7 13.5h9"/></svg>',
        'search'   => '<svg ' . $stroke . '><circle cx="10.5" cy="10.5" r="6.5"/><path d="M20 20l-4.35-4.35"/></svg>',
        'pin'      => '<svg ' . $stroke . '><path d="M12 21s7-7.58 7-12a7 7 0 1 0-14 0c0 4.42 7 12 7 12Z"/><circle cx="12" cy="9" r="2.4"/></svg>',
        'shield'   => '<svg ' . $stroke . '><path d="M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6l7-3Z"/><path d="M9 12l2 2 4-4"/></svg>',
        'users'    => '<svg ' . $stroke . '><circle cx="9" cy="8" r="3.2"/><path d="M3.5 19.5c.6-3.2 2.8-5 5.5-5s4.9 1.8 5.5 5"/><circle cx="17" cy="9.5" r="2.4"/><path d="M15.8 14.6c2.4.2 4.1 1.8 4.7 4.4"/></svg>',
        'route'    => '<svg ' . $stroke . '><circle cx="6" cy="18" r="2.2"/><circle cx="18" cy="6" r="2.2"/><path d="M8 17c5-1 3-7 8-9" stroke-dasharray="2.5 2.5"/></svg>',
        'altitude' => '<svg ' . $stroke . '><path d="M12 20V4"/><path d="M8 8l4-4 4 4"/><path d="M5 20h14"/></svg>',
        'merge'    => '<svg ' . $stroke . '><rect x="3.5" y="3.5" width="11" height="11" rx="2"/><rect x="9.5" y="9.5" width="11" height="11" rx="2"/></svg>',
        'refresh'  => '<svg ' . $stroke . '><path d="M20 11a8 8 0 0 0-14.6-4.4L4 8"/><path d="M4 4v4h4"/><path d="M4 13a8 8 0 0 0 14.6 4.4L20 16"/><path d="M20 20v-4h-4"/></svg>',
        'tower'    => '<svg ' . $stroke . '><path d="M8 21l1.5-10h5L16 21"/><path d="M6.5 7.5h11l-1.5 3.5h-8z"/><path d="M12 3v4.5"/></svg>',
        'palette'  => '<svg ' . $stroke . '><path d="M12 3a9 9 0 1 0 0 18c1.1 0 1.6-.8 1.6-1.6 0-.9-.6-1.3-.6-2.1 0-.9.7-1.5 1.6-1.5H17a4 4 0 0 0 4-4c0-4.9-4-8.8-9-8.8Z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10.5" cy="7.5" r="1"/><circle cx="15" cy="7.5" r="1"/></svg>',
        'check'    => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l4 4 10-10"/></svg>',
        'chevron'  => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>',
        'arrow'    => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 12h15"/><path d="m13 6 6 6-6 6"/></svg>',
        'external' => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M7 17 17 7"/><path d="M8 7h9v9"/></svg>',
        'mail'     => '<svg ' . $stroke . '><rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="m4 7 8 6 8-6"/></svg>',
        'book'     => '<svg ' . $stroke . '><path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5z"/><path d="M4 20.5A2.5 2.5 0 0 0 6.5 23H20v-5"/></svg>',
        'bug'      => '<svg ' . $stroke . '><rect x="7" y="8" width="10" height="12" rx="5"/><path d="M12 8v12M7 13H3M21 13h-4M8 5l1.5 2M16 5l-1.5 2M4 8l3 2M20 8l-3 2M4 19l3-2M20 19l-3-2"/></svg>',
        'clock'    => '<svg ' . $stroke . '><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>',
        'rss'      => '<svg ' . $stroke . '><path d="M5 11a8 8 0 0 1 8 8"/><path d="M5 5a14 14 0 0 1 14 14"/><circle cx="6" cy="18" r="1.2" fill="currentColor" stroke="none"/></svg>',
        'menu'     => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16"/></svg>',
        'close'    => '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>',
        default    => '',
    };
}

function app_store_badge(): string
{
    return '<a class="app-store-badge" href="' . e(APP_STORE_URL) . '" target="_blank" rel="noopener">'
        . '<img src="/images/app-store-badge-black.svg" alt="Download VatSight on the App Store" width="150" height="50">'
        . '</a>';
}

// Every screenshot, described once. Alt text says what is on screen, so each
// image can rank in image search on its own.
function screenshots(): array
{
    return [
        'uk-overview' => [
            'alt'     => 'VatSight live VATSIM map on iPhone showing aircraft and active ATC sectors over the United Kingdom',
            'caption' => 'Live VATSIM traffic and ATC.',
        ],
        'show-inactive-sectors' => [
            'alt'     => 'VatSight layer menu with Merge sectors, Inactive sectors and All airports toggles over a map of Poland showing every sector outline',
            'caption' => 'Show every sector, online or not.',
        ],
        'zoom-details' => [
            'alt'     => 'VatSight zoomed in on Billund, Denmark, showing the EKBI_APP sector label with its 127.580 frequency, an aircraft callsign and an ATIS badge',
            'caption' => 'Zoom in for callsigns and frequencies.',
        ],
        'pilot-details' => [
            'alt'     => 'VatSight flight details for a VATSIM pilot: altitude, speed, heading, squawk, IFR flight plan from KSFO to TNCM, route and remarks',
            'caption' => 'Any pilot’s full flight details.',
        ],
        'track-overlay' => [
            'alt'     => 'VatSight showing a selected flight’s lines to its departure and arrival, with the altitude filter at FL174 highlighting only the sectors at that level',
            'caption' => 'Only the sectors at the flight’s level.',
        ],
        'merged-sectors' => [
            'alt'     => 'VatSight map with merged VATGlasses ATC sectors over the Netherlands and Belgium, one outline per controller',
            'caption' => 'Merge each controller’s sectors.',
        ],
        'blended-sectors' => [
            'alt'     => 'VatSight map showing every active VATGlasses ATC sector with no merging or altitude filtering, overlapping colours blended',
            'caption' => 'Every active sector, unfiltered.',
        ],
        'atc-details' => [
            'alt'     => 'VatSight ATC details for a VATSIM approach controller: frequency, controller info text, rating, facility, server and sector info',
            'caption' => 'Everything about each ATC position.',
        ],
        'light-mode' => [
            'alt'     => 'VatSight in light mode showing VATSIM traffic, ATC sectors and airport service badges over Germany and Switzerland',
            'caption' => 'Light mode, if you prefer it.',
        ],
    ];
}

// A screenshot inside the phone frame. The 750px copy is what most screens
// need; the full-size original is offered to high-density large layouts.
function phone_shot(string $name, array $opts = []): string
{
    $shot = screenshots()[$name] ?? ['alt' => '', 'caption' => ''];
    $eager = $opts['eager'] ?? false;
    $caption = $opts['caption'] ?? $shot['caption'];
    $alt = $opts['alt'] ?? $shot['alt'];
    // The screen is ~90% of the frame's width; these match the CSS widths.
    $sizes = $opts['sizes'] ?? (($opts['class'] ?? '') === 'phone-hero'
        ? '(max-width: 600px) 62vw, 343px'
        : '(max-width: 600px) 62vw, 262px');
    $class = 'phone-card' . (isset($opts['class']) ? ' ' . $opts['class'] : '');

    // Versioned URLs, so a replaced screenshot isn't served stale from cache.
    $small = asset('/images/screenshots/' . $name . '-750.webp');
    $large = asset('/images/screenshots/' . $name . '.webp');
    $img = '<img src="' . e($small) . '"'
        . ' srcset="' . e($small) . ' 750w, ' . e($large) . ' 1206w"'
        . ' sizes="' . e($sizes) . '" width="750" height="1631"'
        . ' alt="' . e($alt) . '"'
        . ($eager ? ' fetchpriority="high"' : ' loading="lazy"') . ' decoding="async">';

    $html = '<figure class="' . e($class) . '">'
        . '<div class="phone-visual"><div class="phone-screen">' . $img . '</div>'
        . '<img class="phone-frame" src="' . e(asset('/images/outline.webp')) . '" alt="" aria-hidden="true" width="890" height="1784"></div>';
    if ($caption !== '') {
        $html .= '<figcaption>' . e($caption) . '</figcaption>';
    }
    return $html . '</figure>';
}

// FAQ items. Answers are trusted HTML written in the page; the schema strips it.
function faq_list(array $faqs): string
{
    $out = '<div class="faq-list">';
    foreach ($faqs as $faq) {
        $out .= '<details class="faq-item"><summary><h3>' . e($faq['q']) . '</h3>' . icon('chevron') . '</summary>'
            . '<p>' . $faq['a'] . '</p></details>';
    }
    return $out . '</div>';
}

function breadcrumbs_html(array $crumbs): string
{
    if (!$crumbs) {
        return '';
    }
    $out = '<nav class="breadcrumbs" aria-label="Breadcrumb"><ol>';
    $last = count($crumbs) - 1;
    foreach ($crumbs as $i => $crumb) {
        $out .= '<li>' . ($i === $last
            ? '<span aria-current="page">' . e($crumb['name']) . '</span>'
            : '<a href="' . e($crumb['path']) . '">' . e($crumb['name']) . '</a>') . '</li>';
    }
    return $out . '</ol></nav>';
}

// The other feature pages, as cards. Cross-links tell search engines how the
// pages relate and keep visitors moving instead of bouncing.
function related_pages(string $current): string
{
    $pages = [
        '/vatsim-map' => ['icon' => 'radar', 'title' => 'VATSIM live map', 'body' => 'Every pilot and controller on one live map, refreshed every 15 seconds.'],
        '/vatglasses' => ['icon' => 'layers', 'title' => 'VATGlasses sectors', 'body' => 'The exact airspace each online controller is working, from VATGlasses data.'],
        '/vatsim-tracker' => ['icon' => 'users', 'title' => 'VATSIM tracker', 'body' => 'Follow any flight by callsign or CID, and see your friends highlighted.'],
        '/guides' => ['icon' => 'book', 'title' => 'VATSIM guides', 'body' => 'ATC positions, VATGlasses and tracking flights, explained.'],
    ];
    unset($pages[$current]);
    $out = '<div class="link-grid">';
    foreach ($pages as $path => $page) {
        $out .= '<a class="link-card" href="' . e($path) . '">'
            . '<span class="feature-icon">' . icon($page['icon']) . '</span>'
            . '<span class="link-card-title">' . e($page['title']) . icon('arrow') . '</span>'
            . '<span class="link-card-body">' . e($page['body']) . '</span></a>';
    }
    return $out . '</div>';
}

// Closing call to action shared by the feature pages and guides.
function download_panel(string $heading = 'Get VatSight on your iPhone', string $body = ''): string
{
    $body = $body !== '' ? $body : 'Free on the App Store for iPhone and iPad. No account, no sign-in, every feature included.';
    return '<section class="final-cta" id="download"><div class="section-inner">'
        . '<h2>' . e($heading) . '</h2>'
        . '<p>' . e($body) . '</p>'
        . '<div class="hero-actions">' . app_store_badge()
        . '<a class="btn-secondary" href="' . e(GITHUB_URL) . '" target="_blank" rel="noopener">' . icon('github') . 'View the source</a>'
        . '</div></div></section>';
}
