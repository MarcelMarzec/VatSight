<?php
// Guides: the index (/guides), tag listings (/guides/tag/{tag}) and each guide
// (/guides/{slug}). The requested slug is only ever compared against guides
// that exist, never used to build a file path.
require_once __DIR__ . '/partials/config.php';
require_once __DIR__ . '/partials/markdown.php';
require_once __DIR__ . '/partials/content.php';

$guides = guides_all();
$slug = isset($_GET['slug']) ? (string) $_GET['slug'] : null;
$tagSlug = isset($_GET['tag']) ? (string) $_GET['tag'] : null;

function guides_not_found(): void
{
    $_SERVER['REDIRECT_STATUS'] = 404;
    require __DIR__ . '/error.php';
    exit;
}

function guide_card(array $guide): string
{
    $out = '<article class="guide-card"><a href="' . e($guide['url']) . '">';
    if ($guide['image'] !== '') {
        $out .= '<span class="guide-card-shot"><img src="' . e($guide['image']) . '" alt="" loading="lazy" decoding="async"></span>';
    }
    $out .= '<span class="guide-card-body">'
        . '<span class="guide-meta"><time datetime="' . e(date('Y-m-d', $guide['updated'] ?: $guide['date'])) . '">'
        . e(($guide['updated'] ? 'Updated ' : '') . content_date($guide['updated'] ?: $guide['date'])) . '</time>'
        . '<span class="sep">·</span><span>' . (int) $guide['minutes'] . ' min read</span>'
        . ($guide['draft'] ? '<span class="sep">·</span><span class="draft-flag">Draft</span>' : '')
        . '</span>'
        . '<span class="guide-card-title">' . e($guide['title']) . '</span>'
        . '<span class="guide-card-summary">' . e($guide['summary']) . '</span>'
        . '<span class="guide-card-more">Read the guide ' . icon('arrow') . '</span>'
        . '</span></a></article>';
    return $out;
}

// ---------- A single guide ----------

if ($slug !== null) {
    $guide = guide_find($slug);
    if ($guide === null) {
        guides_not_found();
    }

    $author = $guide['author'];
    $html = md_to_html($guide['body'], ['dropFirstH1' => true, 'assetBase' => '/content/guides', 'linkBase' => GUIDES_BASE]);
    $toc = $guide['toc'] ? guide_toc($guide['body']) : [];
    $related = guides_related($guide);
    $canonical = abs_url($guide['url']);
    $image = $guide['ogImage'] !== '' ? $guide['ogImage'] : '/images/og-image.jpg';

    $authorNode = ['@type' => 'Person', 'name' => $author['name']];
    if ($author['key'] === DEFAULT_AUTHOR) {
        $authorNode = ['@id' => SITE_URL . '/#marcel'];
    } elseif ($author['url'] !== '') {
        $authorNode['url'] = $author['url'];
    }

    $page = [
        'title'       => $guide['seoTitle'] . ' | VatSight',
        'ogTitle'     => $guide['title'],
        'description' => $guide['description'],
        'path'        => $guide['url'],
        'type'        => 'article',
        'image'       => $image,
        'imageAlt'    => $guide['imageAlt'],
        'noindex'     => $guide['draft'] || $guide['date'] > time(),
        'published'   => $guide['date'],
        'modified'    => $guide['updated'],
        'author'      => $author['name'],
        'tags'        => $guide['tags'],
        'section'     => 'Guides',
        'breadcrumbs' => [['name' => 'Guides', 'path' => GUIDES_BASE], ['name' => $guide['title'], 'path' => $guide['url']]],
        'schema'      => [[
            '@type'            => 'BlogPosting',
            '@id'              => $canonical . '#article',
            'headline'         => $guide['title'],
            'description'      => $guide['description'],
            'image'            => abs_url($image),
            'datePublished'    => date('c', $guide['date']),
            'dateModified'     => date('c', $guide['updated'] ?: $guide['date']),
            'author'           => $authorNode,
            'publisher'        => ['@id' => SITE_URL . '/#organization'],
            'mainEntityOfPage' => ['@id' => $canonical . '#webpage'],
            'isPartOf'         => ['@id' => SITE_URL . '/#website'],
            'articleSection'   => 'Guides',
            'keywords'         => implode(', ', $guide['tags']),
            'wordCount'        => $guide['words'],
            'inLanguage'       => SITE_LOCALE,
        ]],
    ];
    require __DIR__ . '/partials/head.php';
    ?>
        <article class="guide">
            <section class="page-hero guide-hero">
                <div class="section-inner">
                    <?= breadcrumbs_html(array_merge([['name' => 'Home', 'path' => '/']], $page['breadcrumbs'])) ?>
                    <h1><?= e($guide['title']) ?></h1>
                    <p class="page-hero-sub"><?= e($guide['summary']) ?></p>
                    <div class="guide-byline">
                        <?php if ($author['image'] !== ''): ?>
                            <img class="guide-byline-avatar" src="<?= e($author['image']) ?>" alt="" width="40" height="40">
                        <?php endif; ?>
                        <div>
                            <p class="guide-byline-name">By <?php if ($author['url'] !== ''): ?><a href="<?= e($author['url']) ?>" rel="author" target="_blank"><?= e($author['name']) ?></a><?php else: ?><?= e($author['name']) ?><?php endif; ?></p>
                            <p class="guide-meta">
                                <span>Published <time datetime="<?= e(date('Y-m-d', $guide['date'])) ?>"><?= e(content_date($guide['date'])) ?></time></span>
                                <?php if ($guide['updated']): ?>
                                    <span class="sep">·</span>
                                    <span>Updated <time datetime="<?= e(date('Y-m-d', $guide['updated'])) ?>"><?= e(content_date($guide['updated'])) ?></time></span>
                                <?php endif; ?>
                                <span class="sep">·</span>
                                <span><?= (int) $guide['minutes'] ?> min read</span>
                                <?php if ($page['noindex']): ?>
                                    <span class="sep">·</span><span class="draft-flag">Preview: not public yet</span>
                                <?php endif; ?>
                            </p>
                        </div>
                    </div>
                    <?php if ($guide['tags']): ?>
                        <ul class="chip-row" aria-label="Tags">
                            <?php foreach ($guide['tags'] as $tag): ?>
                                <li><a class="chip" href="<?= e(tag_url($tag)) ?>"><?= e($tag) ?></a></li>
                            <?php endforeach; ?>
                        </ul>
                    <?php endif; ?>
                </div>
            </section>

            <section class="guide-body">
                <div class="section-inner guide-layout<?= $toc ? '' : ' guide-layout-single' ?>">
                    <?php if ($toc): ?>
                        <aside class="guide-aside">
                            <details class="toc" open>
                                <summary>On this page <?= icon('chevron') ?></summary>
                                <ol>
                                    <?php foreach ($toc as $item): ?>
                                        <li><a href="#<?= e($item['id']) ?>"><?= e($item['label']) ?></a></li>
                                    <?php endforeach; ?>
                                </ol>
                            </details>
                            <div class="aside-app">
                                <img src="/images/Vatsightlogo.png" alt="" width="40" height="40">
                                <p><strong>VatSight</strong> puts the VATSIM network and VATGlasses sectors on your iPhone. Free, no account.</p>
                                <?= app_store_badge() ?>
                            </div>
                        </aside>
                    <?php endif; ?>

                    <div class="prose">
                        <?= $html ?>

                        <aside class="author-box" aria-label="About the author">
                            <?php if ($author['image'] !== ''): ?>
                                <img src="<?= e($author['image']) ?>" alt="<?= e($author['name']) ?>" width="72" height="72" loading="lazy">
                            <?php endif; ?>
                            <div>
                                <p class="author-box-name"><?= e($author['name']) ?><?php if ($author['role'] !== ''): ?> <span><?= e($author['role']) ?></span><?php endif; ?></p>
                                <?php if ($author['bio'] !== ''): ?><p><?= e($author['bio']) ?></p><?php endif; ?>
                                <?php if ($author['url'] !== ''): ?>
                                    <p class="author-box-links"><a class="link-text" href="<?= e($author['url']) ?>" target="_blank" rel="author noopener">About <?= e(strtok($author['name'], ' ')) ?></a><?php foreach ($author['sameAs'] as $profile): if (str_contains($profile, 'github.com')): ?> · <a class="link-text" href="<?= e($profile) ?>" target="_blank" rel="noopener">GitHub</a><?php endif; endforeach; ?></p>
                                <?php endif; ?>
                            </div>
                        </aside>

                        <p class="guide-feedback">Spotted something out of date? <a class="link-text" href="/contact">Let me know</a> and I'll fix it.</p>
                    </div>
                </div>
            </section>
        </article>

        <?php if ($related): ?>
            <section class="related-guides">
                <div class="section-inner">
                    <div class="section-head">
                        <h2>Keep reading</h2>
                    </div>
                    <div class="guide-grid">
                        <?php foreach ($related as $item): ?>
                            <?= guide_card($item) ?>
                        <?php endforeach; ?>
                    </div>
                </div>
            </section>
        <?php endif; ?>

        <?= download_panel() ?>
    <?php
    require __DIR__ . '/partials/footer.php';
    return;
}

// ---------- The index, or one tag ----------

$allTags = guides_tags($guides);
$activeTag = null;
if ($tagSlug !== null) {
    $activeTag = $allTags[$tagSlug] ?? null;
    if ($activeTag === null) {
        guides_not_found();
    }
    $guides = array_values(array_filter($guides, fn(array $g): bool => in_array($tagSlug, array_map('md_slug', $g['tags']), true)));
}

$path = $activeTag ? tag_url($activeTag['name']) : GUIDES_BASE;
$heading = $activeTag ? 'Guides tagged “' . $activeTag['name'] . '”' : 'VATSIM guides';

$page = [
    'title'       => $activeTag ? $activeTag['name'] . ' guides | VatSight' : 'VATSIM Guides: ATC, VATGlasses & Tracking | VatSight',
    'description' => $activeTag
        ? 'VatSight guides about ' . $activeTag['name'] . '.'
        : 'Plain-English guides to the VATSIM network: ATC positions and callsigns, VATGlasses sectors, tracking flights and friends, and getting more out of VatSight.',
    'path'        => $path,
    'image'       => '/images/og/guides.jpg',
    'imageAlt'    => 'VATSIM guides from VatSight: ATC positions, VATGlasses and tracking flights.',
    // Tag listings repeat the index, so they stay out of search results.
    'noindex'     => $activeTag !== null,
    'webPageType' => 'CollectionPage',
    'breadcrumbs' => $activeTag
        ? [['name' => 'Guides', 'path' => GUIDES_BASE], ['name' => $activeTag['name'], 'path' => $path]]
        : [['name' => 'Guides', 'path' => GUIDES_BASE]],
    'schema'      => $activeTag ? [] : [[
        '@type'           => 'ItemList',
        '@id'             => abs_url(GUIDES_BASE) . '#list',
        'itemListElement' => array_map(fn(int $i, array $g): array => [
            '@type'    => 'ListItem',
            'position' => $i + 1,
            'url'      => abs_url($g['url']),
            'name'     => $g['title'],
        ], array_keys($guides), $guides),
    ]],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="page-hero">
            <div class="section-inner">
                <?= breadcrumbs_html(array_merge([['name' => 'Home', 'path' => '/']], $page['breadcrumbs'])) ?>
                <h1><?= e($heading) ?></h1>
                <p class="page-hero-sub"><?= $activeTag
                    ? e(count($guides) . ' ' . (count($guides) === 1 ? 'guide' : 'guides') . ' with this tag.')
                    : 'How the VATSIM network fits together, explained by the developer of VatSight: who is controlling what, how VATGlasses draws its sectors, and how to follow the flights you care about.' ?></p>
                <?php if ($allTags): ?>
                    <ul class="chip-row" aria-label="Browse by tag">
                        <li><a class="chip<?= $activeTag ? '' : ' is-active' ?>" href="<?= e(GUIDES_BASE) ?>"<?= $activeTag ? '' : ' aria-current="page"' ?>>All guides</a></li>
                        <?php foreach ($allTags as $tag): ?>
                            <li><a class="chip<?= $activeTag && $activeTag['slug'] === $tag['slug'] ? ' is-active' : '' ?>" href="<?= e(tag_url($tag['name'])) ?>"<?= $activeTag && $activeTag['slug'] === $tag['slug'] ? ' aria-current="page"' : '' ?>><?= e($tag['name']) ?> <span><?= (int) $tag['count'] ?></span></a></li>
                        <?php endforeach; ?>
                    </ul>
                <?php endif; ?>
            </div>
        </section>

        <section class="guides-list">
            <div class="section-inner">
                <?php if (!$guides): ?>
                    <p class="empty-state">No guides published yet. <a class="link-text" href="<?= e(NEWSLETTER_URL) ?>">Join the newsletter</a> to hear when the first one goes up.</p>
                <?php else: ?>
                    <div class="guide-grid">
                        <?php foreach ($guides as $guide): ?>
                            <?= guide_card($guide) ?>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
                <p class="guides-feed-link"><a class="link-text" href="/guides/feed.xml"><?= icon('rss') ?> Follow new guides by RSS</a></p>
            </div>
        </section>

        <?= download_panel() ?>
<?php require __DIR__ . '/partials/footer.php'; ?>
