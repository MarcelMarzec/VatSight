<?php
// Site-wide settings and helpers. Every page requires this before any output.

// Marks a legitimate entry point; partials refuse to run without it.
defined('SITE') or define('SITE', true);

const SITE_URL       = 'https://vatsight.com';
const SITE_NAME      = 'VatSight';
const SITE_LOCALE    = 'en-GB';
const APP_STORE_ID   = '6814842201';
const APP_STORE_URL  = 'https://apps.apple.com/app/vatsight/id6814842201';
const GITHUB_URL     = 'https://github.com/MarcelMarzec/VatSight';
const NEWSLETTER_URL = '/phplist/?p=subscribe&id=1';
const CONTACT_EMAIL  = 'contact@marcelmarzec.com';

// Bump when style.css or the images change, so browsers fetch the new copy.
const ASSET_VERSION  = '20261104';

// Contact form: the same Formspree form as marcelmarzec.com/contact, with
// VatSight's own reCAPTCHA site key (public by design; the secret stays in
// Formspree). Formspree must allow vatsight.com, and the reCAPTCHA key must
// list vatsight.com as a domain, or submissions are refused.
const FORMSPREE_URL      = 'https://formspree.io/f/xjgprwan';
const RECAPTCHA_SITE_KEY = '6LeG6Z8sAAAAAEbvZjFDtfbL03IPVo4wtFpe3ZT3';

// Guide authors. A guide's `author:` front matter names one of these keys
// (or the display name); anything unknown falls back to the default author.
const DEFAULT_AUTHOR = 'marcel-marzec';
$authors = [
    'marcel-marzec' => [
        'name'   => 'Marcel Marzec',
        'url'    => 'https://marcelmarzec.com',
        'image'  => '/images/authors/marcel-marzec.webp',
        'role'   => 'Developer of VatSight',
        'bio'    => 'Marcel builds VatSight and maintains the VATGlasses, VATSpy and SimAware airspace data for VATSIM’s Polish vACC (PLVACC). He works with map data for a living, so most of his projects end up on a map.',
        'sameAs' => [
            'https://github.com/MarcelMarzec',
            'https://www.linkedin.com/in/marcelmarzec/',
            'https://marcelmarzec.com',
        ],
    ],
];

// Primary navigation. `match` is the path prefix that marks the link current.
$nav = [
    ['label' => 'Features',   'href' => '/#features'],
    ['label' => 'VATSIM Map', 'href' => '/vatsim-map',     'match' => '/vatsim-map'],
    ['label' => 'VATGlasses', 'href' => '/vatglasses',     'match' => '/vatglasses'],
    ['label' => 'Tracker',    'href' => '/vatsim-tracker', 'match' => '/vatsim-tracker'],
    ['label' => 'Guides',     'href' => '/guides',         'match' => '/guides'],
    ['label' => 'Roadmap',    'href' => '/roadmap',        'match' => '/roadmap'],
    ['label' => 'Contact',    'href' => '/contact',        'match' => '/contact'],
];

// Footer link columns. Every indexable page is linked from here, so each one
// is at most a click from any other page.
$footerGroups = [
    'App' => [
        ['label' => 'VATSIM live map',    'href' => '/vatsim-map'],
        ['label' => 'VATGlasses sectors', 'href' => '/vatglasses'],
        ['label' => 'VATSIM tracker',     'href' => '/vatsim-tracker'],
        ['label' => 'Download on the App Store', 'href' => APP_STORE_URL, 'external' => true],
    ],
    'Resources' => [
        ['label' => 'Guides',    'href' => '/guides'],
        ['label' => 'Roadmap',   'href' => '/roadmap'],
        ['label' => 'FAQ',       'href' => '/#faq'],
        ['label' => 'RSS feed',  'href' => '/guides/feed.xml'],
    ],
    'Project' => [
        ['label' => 'Contact',        'href' => '/contact'],
        ['label' => 'Newsletter',     'href' => NEWSLETTER_URL],
        ['label' => 'Source on GitHub', 'href' => GITHUB_URL, 'external' => true],
        ['label' => 'Privacy policy', 'href' => '/privacy_policy'],
    ],
];

// Static pages for the XML sitemap. Update `lastmod` when a page's content
// changes meaningfully; guides add themselves from their front matter.
$sitemapPages = [
    '/' => [
        'lastmod' => '2026-11-04',
        'images'  => [
            '/images/og-image.jpg',
            '/images/screenshots/uk-overview.webp',
            '/images/screenshots/show-inactive-sectors.webp',
            '/images/screenshots/zoom-details.webp',
            '/images/screenshots/pilot-details.webp',
            '/images/screenshots/track-overlay.webp',
            '/images/screenshots/merged-sectors.webp',
            '/images/screenshots/blended-sectors.webp',
            '/images/screenshots/atc-details.webp',
            '/images/screenshots/light-mode.webp',
        ],
    ],
    '/vatsim-map'     => ['lastmod' => '2026-11-04', 'images' => ['/images/screenshots/uk-overview.webp', '/images/screenshots/zoom-details.webp']],
    '/vatglasses'     => ['lastmod' => '2026-11-04', 'images' => ['/images/screenshots/merged-sectors.webp', '/images/screenshots/atc-details.webp']],
    '/vatsim-tracker' => ['lastmod' => '2026-11-04', 'images' => ['/images/screenshots/pilot-details.webp', '/images/screenshots/track-overlay.webp']],
    '/guides'         => ['lastmod' => null],
    '/roadmap'        => ['lastmod' => '2026-11-04'],
    '/contact'        => ['lastmod' => '2026-11-04'],
    '/privacy_policy' => ['lastmod' => '2026-11-04'],
];

// ---------- Helpers ----------

function e(?string $text): string
{
    return htmlspecialchars((string) $text, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

// Absolute URL for a site-relative path; absolute URLs pass through.
function abs_url(string $path): string
{
    if (preg_match('#^https?://#i', $path)) {
        return $path;
    }
    return SITE_URL . '/' . ltrim($path, '/');
}

// Content-Security-Policy for our own pages. Pages that need more (the contact
// form's reCAPTCHA and Formspree) pass extra sources per directive.
function csp_header(array $extra = []): string
{
    $policy = [
        'default-src'     => ["'self'"],
        'script-src'      => ["'none'"],
        'style-src'       => ["'self'", 'https://fonts.googleapis.com'],
        'font-src'        => ['https://fonts.gstatic.com'],
        'img-src'         => ["'self'", 'data:'],
        'form-action'     => ["'self'"],
        'frame-ancestors' => ["'self'"],
        'base-uri'        => ["'self'"],
        'object-src'      => ["'none'"],
    ];
    foreach ($extra as $directive => $sources) {
        $current = $policy[$directive] ?? ["'self'"];
        if ($current === ["'none'"]) {
            $current = [];
        }
        $policy[$directive] = array_values(array_unique(array_merge($current, $sources)));
    }
    $parts = [];
    foreach ($policy as $directive => $sources) {
        $parts[] = $directive . ' ' . implode(' ', $sources);
    }
    $parts[] = 'upgrade-insecure-requests';
    return implode('; ', $parts);
}

function asset(string $path): string
{
    return $path . (str_contains($path, '?') ? '&' : '?') . 'v=' . ASSET_VERSION;
}

function author_profile(?string $key): array
{
    global $authors;
    $key = trim((string) $key);
    if ($key !== '') {
        if (isset($authors[$key])) {
            return $authors[$key] + ['key' => $key];
        }
        foreach ($authors as $slug => $author) {
            if (strcasecmp($author['name'], $key) === 0) {
                return $author + ['key' => $slug];
            }
        }
        return ['key' => '', 'name' => $key, 'url' => '', 'image' => '', 'role' => '', 'bio' => '', 'sameAs' => []];
    }
    return $authors[DEFAULT_AUTHOR] + ['key' => DEFAULT_AUTHOR];
}

// ---------- Structured data shared by every page ----------

function schema_core_nodes(): array
{
    $marcel = author_profile(DEFAULT_AUTHOR);
    return [
        [
            '@type'       => 'WebSite',
            '@id'         => SITE_URL . '/#website',
            'url'         => SITE_URL . '/',
            'name'        => SITE_NAME,
            'alternateName' => ['VatSight.com', 'VatSight VATSIM app'],
            'inLanguage'  => SITE_LOCALE,
            'publisher'   => ['@id' => SITE_URL . '/#organization'],
        ],
        [
            '@type'   => 'Organization',
            '@id'     => SITE_URL . '/#organization',
            'name'    => SITE_NAME,
            'url'     => SITE_URL . '/',
            'logo'    => [
                '@type'      => 'ImageObject',
                '@id'        => SITE_URL . '/#logo',
                'url'        => SITE_URL . '/images/Vatsightlogo.png',
                'contentUrl' => SITE_URL . '/images/Vatsightlogo.png',
                'width'      => 1024,
                'height'     => 1024,
                'caption'    => SITE_NAME,
            ],
            'image'   => ['@id' => SITE_URL . '/#logo'],
            'founder' => ['@id' => SITE_URL . '/#marcel'],
            'sameAs'  => [GITHUB_URL, APP_STORE_URL],
        ],
        [
            '@type'    => 'Person',
            '@id'      => SITE_URL . '/#marcel',
            'name'     => $marcel['name'],
            'url'      => $marcel['url'],
            'jobTitle' => $marcel['role'],
            'sameAs'   => $marcel['sameAs'],
        ],
    ];
}

function schema_app_node(): array
{
    return [
        '@type'               => 'MobileApplication',
        '@id'                 => SITE_URL . '/#app',
        'name'                => SITE_NAME,
        'url'                 => SITE_URL . '/',
        'description'         => 'VatSight is a free VATSIM app for iPhone and iPad: a live map of every pilot and controller on the network, VATGlasses ATC sectors, airport traffic and friend tracking.',
        'downloadUrl'         => APP_STORE_URL,
        'installUrl'          => APP_STORE_URL,
        'image'               => SITE_URL . '/images/og-image.jpg',
        'screenshot'          => array_map('abs_url', [
            '/images/screenshots/uk-overview.webp',
            '/images/screenshots/merged-sectors.webp',
            '/images/screenshots/pilot-details.webp',
            '/images/screenshots/atc-details.webp',
            '/images/screenshots/track-overlay.webp',
            '/images/screenshots/light-mode.webp',
        ]),
        'softwareVersion'     => '1.0',
        'applicationCategory' => 'TravelApplication',
        'applicationSubCategory' => 'Flight simulation',
        'operatingSystem'     => 'iOS 26, iPadOS 26',
        'isAccessibleForFree' => true,
        'author'              => ['@id' => SITE_URL . '/#marcel'],
        'publisher'           => ['@id' => SITE_URL . '/#organization'],
        'offers'              => ['@type' => 'Offer', 'price' => '0', 'priceCurrency' => 'GBP'],
        'sameAs'              => [APP_STORE_URL, GITHUB_URL],
    ];
}

// FAQPage node from the same list the page renders, so the two never drift.
function schema_faq_node(array $faqs, string $path): array
{
    return [
        '@type'      => 'FAQPage',
        '@id'        => abs_url($path) . '#faq',
        'mainEntity' => array_map(fn(array $f): array => [
            '@type'          => 'Question',
            'name'           => $f['q'],
            'acceptedAnswer' => [
                '@type' => 'Answer',
                'text'  => trim(preg_replace('/\s+/', ' ', strip_tags($f['a']))),
            ],
        ], $faqs),
    ];
}
