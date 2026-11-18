<?php
defined('SITE') or exit;
// Opens the document, the nav and <main>. A page sets $page first, then
// requires this; partials/footer.php closes everything again.
//
// $page keys:
//   title, description, path   required
//   image, imageAlt            social preview (site-relative or absolute)
//   type                       'website' (default) or 'article'
//   noindex                    true for pages that should stay out of search
//   breadcrumbs                [['name' => ..., 'path' => ...], ...] (Home is added)
//   schema                     extra JSON-LD nodes for the @graph
//   csp                        extra Content-Security-Policy sources per directive
//   published, modified        timestamps, for articles
//   author, tags, section      article metadata
//   cache                      Cache-Control value (default no-cache)
require_once __DIR__ . '/components.php';

$page += [
    'image'       => '/images/og-image.jpg',
    'imageAlt'    => 'VatSight: the VATSIM network, live on your iPhone. Live traffic and VATGlasses ATC sectors on a map.',
    'type'        => 'website',
    'noindex'     => false,
    'breadcrumbs' => [],
    'schema'      => [],
    'csp'         => [],
    'published'   => null,
    'modified'    => null,
    'author'      => null,
    'tags'        => [],
    'section'     => '',
    'cache'       => 'no-cache',
];

header('Cache-Control: ' . $page['cache']);
header('Content-Security-Policy: ' . csp_header($page['csp']));

$canonical = abs_url($page['path']);
$ogImage   = abs_url($page['image']);
$ogLocal   = parse_url($page['image'], PHP_URL_HOST) === null
    ? @getimagesize(__DIR__ . '/..' . parse_url($page['image'], PHP_URL_PATH))
    : false;

// Breadcrumbs always start at Home; the page supplies the rest.
$crumbs = $page['breadcrumbs'] ? array_merge([['name' => 'Home', 'path' => '/']], $page['breadcrumbs']) : [];

$graph = schema_core_nodes();
if (!$page['noindex']) {
    $webPage = [
        '@type'      => $page['webPageType'] ?? 'WebPage',
        '@id'        => $canonical . '#webpage',
        'url'        => $canonical,
        'name'       => $page['title'],
        'description' => $page['description'],
        'inLanguage' => SITE_LOCALE,
        'isPartOf'   => ['@id' => SITE_URL . '/#website'],
        'primaryImageOfPage' => ['@type' => 'ImageObject', 'url' => $ogImage],
    ];
    if ($crumbs) {
        $webPage['breadcrumb'] = ['@id' => $canonical . '#breadcrumb'];
        $graph[] = [
            '@type' => 'BreadcrumbList',
            '@id'   => $canonical . '#breadcrumb',
            'itemListElement' => array_map(fn(int $i, array $c): array => [
                '@type'    => 'ListItem',
                'position' => $i + 1,
                'name'     => $c['name'],
                'item'     => abs_url($c['path']),
            ], array_keys($crumbs), $crumbs),
        ];
    }
    if (!empty($page['about'])) {
        $webPage['about'] = ['@id' => $page['about']];
    }
    $graph[] = $webPage;
}
$graph = array_merge($graph, $page['schema']);
$jsonFlags = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP;
?>
<!DOCTYPE html>
<html lang="en-GB">

<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($page['title']) ?></title>
    <meta name="description" content="<?= e($page['description']) ?>">
<?php if ($page['noindex']): ?>
    <meta name="robots" content="noindex, follow">
<?php else: ?>
    <meta name="robots" content="index, follow, max-image-preview:large, max-snippet:-1">
    <link rel="canonical" href="<?= e($canonical) ?>">
<?php endif; ?>
    <meta name="author" content="<?= e($page['author'] ?? 'Marcel Marzec') ?>">
    <meta name="theme-color" content="#090909">
    <meta name="apple-itunes-app" content="app-id=<?= e(APP_STORE_ID) ?>">

    <meta property="og:type" content="<?= e($page['type']) ?>">
    <meta property="og:site_name" content="<?= e(SITE_NAME) ?>">
    <meta property="og:locale" content="en_GB">
    <meta property="og:title" content="<?= e($page['ogTitle'] ?? $page['title']) ?>">
    <meta property="og:description" content="<?= e($page['description']) ?>">
    <meta property="og:url" content="<?= e($canonical) ?>">
    <meta property="og:image" content="<?= e($ogImage) ?>">
<?php if ($ogLocal): ?>
    <meta property="og:image:width" content="<?= (int) $ogLocal[0] ?>">
    <meta property="og:image:height" content="<?= (int) $ogLocal[1] ?>">
    <meta property="og:image:type" content="<?= e($ogLocal['mime']) ?>">
<?php endif; ?>
    <meta property="og:image:alt" content="<?= e($page['imageAlt']) ?>">
<?php if ($page['type'] === 'article' && $page['published']): ?>
    <meta property="article:published_time" content="<?= e(date('c', $page['published'])) ?>">
<?php if ($page['modified']): ?>
    <meta property="article:modified_time" content="<?= e(date('c', $page['modified'])) ?>">
<?php endif; ?>
<?php if ($page['section'] !== ''): ?>
    <meta property="article:section" content="<?= e($page['section']) ?>">
<?php endif; ?>
<?php foreach ($page['tags'] as $tag): ?>
    <meta property="article:tag" content="<?= e($tag) ?>">
<?php endforeach; ?>
<?php endif; ?>
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="<?= e($page['ogTitle'] ?? $page['title']) ?>">
    <meta name="twitter:description" content="<?= e($page['description']) ?>">
    <meta name="twitter:image" content="<?= e($ogImage) ?>">
    <meta name="twitter:image:alt" content="<?= e($page['imageAlt']) ?>">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Google+Sans:ital,opsz,wght@0,17..18,400..700;1,17..18,400..700&amp;display=swap">
    <link rel="stylesheet" href="<?= e(asset('/style/style.css')) ?>">

    <link rel="icon" type="image/png" href="/images/favicon/favicon-96x96.png?v=20260509" sizes="96x96">
    <link rel="icon" type="image/svg+xml" href="/images/favicon/favicon.svg?v=20260509">
    <link rel="shortcut icon" href="/images/favicon/favicon.ico?v=20260509">
    <link rel="apple-touch-icon" sizes="180x180" href="/images/favicon/apple-touch-icon.png?v=20260509">
    <meta name="apple-mobile-web-app-title" content="VatSight">
    <link rel="manifest" href="/images/favicon/site.webmanifest?v=20260509">
    <link rel="alternate" type="application/rss+xml" title="VatSight guides" href="<?= e(SITE_URL) ?>/guides/feed.xml">
<?php foreach (($page['preload'] ?? []) as $preload): ?>
    <link rel="preload" as="image" href="<?= e($preload['href']) ?>"<?= isset($preload['srcset']) ? ' imagesrcset="' . e($preload['srcset']) . '" imagesizes="' . e($preload['sizes'] ?? '') . '"' : '' ?> fetchpriority="high">
<?php endforeach; ?>
<?php if (!$page['noindex']): ?>
    <script type="application/ld+json"><?= json_encode(['@context' => 'https://schema.org', '@graph' => $graph], $jsonFlags) ?></script>
<?php endif; ?>
</head>

<body>

    <a class="skip-link" href="#main-content">Skip to main content</a>

    <?php require __DIR__ . '/header.php'; ?>

    <main id="main-content">
