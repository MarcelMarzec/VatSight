<?php
// RSS 2.0 feed of the guides, served at /guides/feed.xml by a rewrite.
require_once __DIR__ . '/partials/config.php';
require_once __DIR__ . '/partials/markdown.php';
require_once __DIR__ . '/partials/content.php';

header('Content-Type: application/rss+xml; charset=utf-8');
header('Cache-Control: public, max-age=3600');

$guides = array_slice(guides_all(false), 0, 20);
$built = 0;
foreach ($guides as $guide) {
    $built = max($built, $guide['updated'] ?: $guide['date']);
}
$built = $built ?: time();

echo '<?xml version="1.0" encoding="UTF-8"?>', "\n";
?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>VatSight guides</title>
    <link><?= e(abs_url(GUIDES_BASE)) ?></link>
    <atom:link href="<?= e(abs_url('/guides/feed.xml')) ?>" rel="self" type="application/rss+xml"/>
    <description>Plain-English guides to the VATSIM network, VATGlasses and VatSight.</description>
    <language>en-gb</language>
    <lastBuildDate><?= e(date(DATE_RSS, $built)) ?></lastBuildDate>
<?php foreach ($guides as $guide): ?>
    <item>
      <title><?= e($guide['title']) ?></title>
      <link><?= e(abs_url($guide['url'])) ?></link>
      <guid isPermaLink="true"><?= e(abs_url($guide['url'])) ?></guid>
      <pubDate><?= e(date(DATE_RSS, $guide['date'])) ?></pubDate>
      <dc:creator><?= e($guide['author']['name']) ?></dc:creator>
      <description><?= e($guide['description']) ?></description>
<?php foreach ($guide['tags'] as $tag): ?>
      <category><?= e($tag) ?></category>
<?php endforeach; ?>
    </item>
<?php endforeach; ?>
  </channel>
</rss>
