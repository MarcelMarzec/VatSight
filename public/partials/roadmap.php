<?php
defined('SITE') or exit;
// Roadmap, shared by the home page and /roadmap. The releases are written in
// CONTENT_DIR/roadmap.md (see the comments at the top of that file).
require_once __DIR__ . '/markdown.php';
require_once __DIR__ . '/content.php';

const ROADMAP_FILE = CONTENT_DIR . '/roadmap.md';
const ROADMAP_STATUSES = ['done', 'current', 'planned'];

// ['updated' => ?int, 'releases' => [...]], releases in file order (newest first).
function roadmap_data(): array
{
    static $data = null;
    if ($data !== null) {
        return $data;
    }

    $raw = @file_get_contents(ROADMAP_FILE);
    [$meta, $body] = content_front_matter($raw === false ? '' : $raw);

    $releases = [];
    foreach (preg_split('/^##\s+/m', $body) as $i => $chunk) {
        if ($i === 0 || trim($chunk) === '') {
            continue; // text before the first release heading
        }
        $lines = preg_split('/\R/', rtrim($chunk));
        $heading = trim(array_shift($lines));
        [$version, $title] = array_pad(preg_split('/\s+[-–—:]\s+|:\s+/u', $heading, 2), 2, '');
        if ($title === '') {
            [$version, $title] = ['', $version];
        }

        $release = ['status' => 'planned', 'date' => '', 'version' => trim($version), 'title' => trim($title), 'summary' => '', 'items' => []];
        $paragraph = [];
        $inFields = true;
        foreach ($lines as $line) {
            $trimmed = trim($line);
            if ($inFields && preg_match('/^(status|date)\s*:\s*(.*)$/i', $trimmed, $m)) {
                $release[strtolower($m[1])] = trim($m[2]);
                continue;
            }
            if ($trimmed !== '') {
                $inFields = false;
            }
            if (preg_match('/^[-*+]\s+(.+)$/', $trimmed, $m)) {
                $release['items'][] = $m[1];
            } elseif ($trimmed !== '' && !$release['items']) {
                $paragraph[] = $trimmed;
            }
        }
        $release['status'] = strtolower($release['status']);
        if (!in_array($release['status'], ROADMAP_STATUSES, true)) {
            $release['status'] = 'planned';
        }
        $release['summary'] = implode(' ', $paragraph);
        $releases[] = $release;
    }

    return $data = [
        'updated'  => strtotime(content_string($meta['updated'] ?? '')) ?: null,
        'releases' => $releases,
    ];
}

function roadmap_releases(): array
{
    return roadmap_data()['releases'];
}

function roadmap_status_label(string $status): string
{
    return ['done' => 'Released', 'current' => 'Latest release', 'planned' => 'Planned'][$status] ?? '';
}

// A vertical timeline, newest first. $only limits it to some statuses, e.g.
// ['current', 'planned']; $oldestFirst flips the order (the home page reads
// left to right, now then next).
function roadmap_timeline(bool $expanded = false, ?array $only = null, bool $oldestFirst = false): string
{
    $releases = roadmap_releases();
    if ($only !== null) {
        $releases = array_values(array_filter($releases, fn(array $r): bool => in_array($r['status'], $only, true)));
    }
    if ($oldestFirst) {
        $releases = array_reverse($releases);
    }

    $out = '<ol class="roadmap-timeline">';
    foreach ($releases as $release) {
        $status = $release['status'];
        $id = $release['version'] !== '' ? ' id="' . e(md_slug($release['version'])) . '"' : '';
        $out .= '<li class="roadmap-item is-' . $status . '"' . $id . '>'
            . '<span class="roadmap-marker" aria-hidden="true"></span>'
            . '<div class="roadmap-when">'
            . '<span class="roadmap-version">' . e($release['version']) . '</span>'
            . ($release['date'] !== '' ? '<span class="roadmap-date">' . e($release['date']) . '</span>' : '')
            . '</div>'
            . '<div class="roadmap-content">'
            . '<span class="roadmap-status">' . e(roadmap_status_label($status)) . '</span>'
            . '<h3>' . e($release['title']) . '</h3>'
            . ($release['summary'] !== '' ? '<p>' . md_inline($release['summary']) . '</p>' : '');
        if ($release['items']) {
            $list = '<ul>';
            foreach ($release['items'] as $item) {
                $list .= '<li>' . md_inline($item) . '</li>';
            }
            $list .= '</ul>';
            $out .= $expanded
                ? '<div class="roadmap-items">' . $list . '</div>'
                : '<details class="roadmap-details"><summary>What’s included' . icon('chevron') . '</summary>' . $list . '</details>';
        }
        $out .= '</div></li>';
    }
    return $out . '</ol>';
}
