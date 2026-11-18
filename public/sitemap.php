<?php
// XML sitemap, served at /sitemap.xml by a rewrite. Static pages come from
// $sitemapPages in partials/config.php; guides add themselves, with their
// own modified dates, so publishing a guide needs no change here.
require_once __DIR__ . '/partials/config.php';
require_once __DIR__ . '/partials/markdown.php';
require_once __DIR__ . '/partials/content.php';

header('Content-Type: application/xml; charset=utf-8');
header('Cache-Control: public, max-age=3600');

$guides = guides_all();
$latestGuide = 0;
$entries = [];

foreach ($guides as $guide) {
    $modified = $guide['updated'] ?: $guide['date'];
    $latestGuide = max($latestGuide, $modified);
    $entries[] = [
        'loc'     => $guide['url'],
        'lastmod' => date('Y-m-d', $modified),
        'images'  => $guide['ogImage'] !== '' ? [$guide['ogImage']] : [],
    ];
}

$static = [];
foreach ($sitemapPages as $path => $meta) {
    $lastmod = $meta['lastmod'];
    if ($path === '/guides') {
        $lastmod = $latestGuide ? date('Y-m-d', $latestGuide) : null;
    }
    $static[] = ['loc' => $path, 'lastmod' => $lastmod, 'images' => $meta['images'] ?? []];
}
$entries = array_merge($static, $entries);

echo '<?xml version="1.0" encoding="UTF-8"?>', "\n";
?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
        xmlns:image="http://www.google.com/schemas/sitemap-image/1.1">
<?php foreach ($entries as $entry): ?>
  <url>
    <loc><?= e(abs_url($entry['loc'])) ?></loc>
<?php if ($entry['lastmod']): ?>
    <lastmod><?= e($entry['lastmod']) ?></lastmod>
<?php endif; ?>
<?php foreach ($entry['images'] as $image): ?>
    <image:image>
      <image:loc><?= e(abs_url($image)) ?></image:loc>
    </image:image>
<?php endforeach; ?>
  </url>
<?php endforeach; ?>
</urlset>
