<?php
defined('SITE') or exit;
// Site navigation. Marks the link for the current section with aria-current.
$currentPath = $page['path'] ?? '';
?>
    <header class="nav">
        <div class="nav-inner">
            <a class="nav-brand" href="/">
                <img src="/images/Vatsightlogo.png" alt="" width="26" height="26">
                <span>VatSight</span>
            </a>
            <input type="checkbox" id="nav-toggle" class="nav-toggle-input" aria-label="Show menu">
            <nav class="nav-links" aria-label="Primary">
<?php foreach ($nav as $link):
    $isCurrent = isset($link['match']) && ($currentPath === $link['match'] || str_starts_with($currentPath, $link['match'] . '/'));
?>
                <a href="<?= e($link['href']) ?>"<?= $isCurrent ? ' aria-current="page"' : '' ?>><?= e($link['label']) ?></a>
<?php endforeach; ?>
            </nav>
            <div class="nav-right">
                <a class="nav-cta" href="<?= e(GITHUB_URL) ?>" target="_blank" rel="noopener">
                    <?= icon('github') ?>
                    GitHub
                </a>
                <label for="nav-toggle" class="nav-toggle" aria-hidden="true">
                    <span class="icon-menu"><?= icon('menu') ?></span>
                    <span class="icon-close"><?= icon('close') ?></span>
                </label>
            </div>
        </div>
        <label for="nav-toggle" class="nav-backdrop" aria-hidden="true"></label>
    </header>
