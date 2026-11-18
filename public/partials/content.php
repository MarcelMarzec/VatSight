<?php
defined('SITE') or exit;
// Reads the guides: one Markdown file per guide in content/guides, with
// front matter at the top (see content/guides/_template.md for every field).
// Files starting with an underscore are ignored. Nothing is cached: at this
// number of files the reads cost less than the machinery to avoid them.

const GUIDES_DIR  = __DIR__ . '/../content/guides';
const GUIDES_BASE = '/guides';

// Drafts and future-dated guides are visible on a local dev server only, so
// they can be previewed before they go live.
function guides_preview_mode(): bool
{
    $host = strtolower(explode(':', $_SERVER['HTTP_HOST'] ?? '')[0]);
    return in_array($host, ['localhost', '127.0.0.1', '[::1]'], true) || str_ends_with($host, '.localhost');
}

// Splits YAML-ish front matter off the top of a file. Supports key: value,
// inline lists [a, b] and dashed lists, which is what Obsidian writes.
function content_front_matter(string $raw): array
{
    if (!preg_match('/^(?:\xEF\xBB\xBF)?---\R(.*?)\R---\R?(.*)$/s', $raw, $m)) {
        return [[], $raw];
    }

    $meta = [];
    $key = null;
    foreach (preg_split('/\R/', $m[1]) as $line) {
        if (trim($line) === '' || str_starts_with(trim($line), '#')) {
            continue;
        }
        if (preg_match('/^\s*-\s+(.*)$/', $line, $item)) {
            if ($key !== null) {
                $meta[$key] = array_merge((array) ($meta[$key] ?: []), [content_scalar($item[1])]);
            }
            continue;
        }
        if (preg_match('/^([A-Za-z0-9_-]+)\s*:\s*(.*)$/', $line, $pair)) {
            $key = strtolower($pair[1]);
            $value = trim($pair[2]);
            if ($value === '') {
                $meta[$key] = [];
                continue;
            }
            if (preg_match('/^\[(.*)\]$/', $value, $list)) {
                $meta[$key] = array_values(array_filter(
                    array_map('content_scalar', explode(',', $list[1])),
                    fn(string $v): bool => $v !== ''
                ));
                $key = null;
                continue;
            }
            $meta[$key] = content_scalar($value);
            $key = null;
        }
    }
    return [$meta, $m[2]];
}

function content_scalar(string $value): string
{
    $value = trim($value);
    if (strlen($value) > 1 && (
        ($value[0] === '"' && str_ends_with($value, '"'))
        || ($value[0] === "'" && str_ends_with($value, "'"))
    )) {
        $value = substr($value, 1, -1);
    }
    return trim($value);
}

function content_string(mixed $value): string
{
    return is_array($value) ? '' : trim((string) $value);
}

function content_truthy(mixed $value): bool
{
    return in_array(strtolower(content_string($value)), ['true', 'yes', '1'], true);
}

function content_list(mixed $value): array
{
    $items = is_array($value) ? $value : (content_string($value) === '' ? [] : explode(',', (string) $value));
    return array_values(array_filter(array_map('trim', $items), fn(string $v): bool => $v !== ''));
}

// Every guide, newest first. Drafts and future dates are left out unless
// previewing locally.
function guides_all(?bool $includeHidden = null): array
{
    static $cache = [];
    $includeHidden ??= guides_preview_mode();
    $key = $includeHidden ? 'all' : 'live';
    if (isset($cache[$key])) {
        return $cache[$key];
    }

    $guides = [];
    foreach (glob(GUIDES_DIR . '/*.md') ?: [] as $file) {
        if (str_starts_with(basename($file), '_')) {
            continue;
        }
        $guide = guide_read($file);
        if ($guide === null) {
            continue;
        }
        if (!$includeHidden && ($guide['draft'] || $guide['date'] > time())) {
            continue;
        }
        $guides[] = $guide;
    }
    usort($guides, fn(array $a, array $b): int => $b['date'] <=> $a['date']);
    return $cache[$key] = $guides;
}

function guide_read(string $path): ?array
{
    $raw = @file_get_contents($path);
    if ($raw === false) {
        return null;
    }
    [$meta, $body] = content_front_matter($raw);

    $name  = preg_replace('/\.md$/i', '', basename($path));
    $slug  = md_slug(content_string($meta['slug'] ?? '')) ?: md_slug($name);
    $title = content_string($meta['title'] ?? '') ?: $name;

    $date = strtotime(content_string($meta['date'] ?? '')) ?: (filemtime($path) ?: time());
    $updated = strtotime(content_string($meta['updated'] ?? '')) ?: null;
    if ($updated !== null && $updated <= $date) {
        $updated = null;
    }

    $tags = content_list($meta['tags'] ?? []);
    $assetBase = '/content/guides';

    // The social preview and card image. Only set explicitly: the phone
    // screenshots in most guides are too tall to make good previews, so
    // without one the site's default 1200x630 card is used.
    $image = content_string($meta['image'] ?? '');
    $image = $image !== '' ? (md_resolve_asset($image, $assetBase) ?? '') : '';

    // Social preview: the explicit image, else the card made by
    // tools/make-og-images.py, else (in guides.php) the site default.
    $ogImage = $image;
    if ($ogImage === '' && is_file(__DIR__ . '/../images/og/guides/' . $slug . '.jpg')) {
        $ogImage = '/images/og/guides/' . $slug . '.jpg';
    }

    $description = content_string($meta['description'] ?? '') ?: content_excerpt($body);
    $words = str_word_count(strip_tags($body));

    return [
        'path'        => $path,
        'slug'        => $slug,
        'url'         => GUIDES_BASE . '/' . $slug,
        'title'       => $title,
        'seoTitle'    => content_string($meta['seo_title'] ?? '') ?: $title,
        'description' => $description,
        'summary'     => content_string($meta['summary'] ?? '') ?: $description,
        'author'      => author_profile(content_string($meta['author'] ?? '')),
        'tags'        => $tags,
        'image'       => $image,
        'ogImage'     => $ogImage,
        'imageAlt'    => content_string($meta['image_alt'] ?? '') ?: $title,
        'related'     => array_map('md_slug', content_list($meta['related'] ?? [])),
        'draft'       => content_truthy($meta['draft'] ?? false),
        'toc'         => !in_array(strtolower(content_string($meta['toc'] ?? '')), ['false', 'no', '0'], true),
        'date'        => $date,
        'updated'     => $updated,
        'body'        => $body,
        'words'       => $words,
        'minutes'     => max(1, (int) round($words / 220)),
    ];
}

// First paragraph of the body, trimmed to something a meta description can use.
function content_excerpt(string $body, int $limit = 155): string
{
    foreach (preg_split('/\R\s*\R/', $body) as $block) {
        $block = trim($block);
        if ($block === '' || preg_match('/^(#|!\[|\||>|```|-{3,}|[*+-]\s|\d+[.)]\s)/', $block)) {
            continue;
        }
        $text = trim(preg_replace('/\s+/', ' ', strip_tags(md_inline($block))));
        $text = html_entity_decode($text, ENT_QUOTES, 'UTF-8');
        if (mb_strlen($text) <= $limit) {
            return $text;
        }
        return rtrim(mb_substr($text, 0, $limit - 1), " ,.;:") . '…';
    }
    return '';
}

function guide_find(string $slug): ?array
{
    foreach (guides_all() as $guide) {
        if ($guide['slug'] === $slug) {
            return $guide;
        }
    }
    return null;
}

// Tag name => ['name', 'slug', 'count'], most used first.
function guides_tags(array $guides): array
{
    $tags = [];
    foreach ($guides as $guide) {
        foreach ($guide['tags'] as $tag) {
            $slug = md_slug($tag);
            $tags[$slug] ??= ['name' => $tag, 'slug' => $slug, 'count' => 0];
            $tags[$slug]['count']++;
        }
    }
    uasort($tags, fn(array $a, array $b): int => [$b['count'], $a['name']] <=> [$a['count'], $b['name']]);
    return $tags;
}

function tag_url(string $tag): string
{
    return GUIDES_BASE . '/tag/' . md_slug($tag);
}

// Guides to read next: the ones named in `related:` first, then those sharing
// the most tags, then the newest.
function guides_related(array $guide, int $limit = 3): array
{
    $others = array_values(array_filter(guides_all(), fn(array $g): bool => $g['slug'] !== $guide['slug']));
    $picked = [];
    foreach ($guide['related'] as $slug) {
        foreach ($others as $other) {
            if ($other['slug'] === $slug) {
                $picked[$slug] = $other;
            }
        }
    }
    $mine = array_map('md_slug', $guide['tags']);
    usort($others, function (array $a, array $b) use ($mine): int {
        $sa = count(array_intersect($mine, array_map('md_slug', $a['tags'])));
        $sb = count(array_intersect($mine, array_map('md_slug', $b['tags'])));
        return [$sb, $b['date']] <=> [$sa, $a['date']];
    });
    foreach ($others as $other) {
        $picked[$other['slug']] ??= $other;
    }
    return array_slice(array_values($picked), 0, $limit);
}

// Table of contents from the guide's ## headings, skipping fenced code.
function guide_toc(string $body): array
{
    $toc = [];
    $inCode = false;
    foreach (preg_split('/\R/', $body) as $line) {
        if (preg_match('/^\s*```/', $line)) {
            $inCode = !$inCode;
            continue;
        }
        if (!$inCode && preg_match('/^##\s+(.+)$/', $line, $m)) {
            $label = html_entity_decode(strip_tags(md_inline(trim($m[1]))), ENT_QUOTES, 'UTF-8');
            $toc[] = ['id' => md_slug($m[1]), 'label' => $label];
        }
    }
    return $toc;
}

function content_date(int $timestamp): string
{
    return date('j F Y', $timestamp);
}
