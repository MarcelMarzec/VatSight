<?php
require_once __DIR__ . '/partials/config.php';
require_once __DIR__ . '/partials/roadmap.php';

$roadmap = roadmap_data();

$page = [
    'title'       => 'VatSight Roadmap & Release Notes',
    'description' => 'Where VatSight has been and where it’s going: every release of the VATSIM app for iPhone, from the first map to the App Store launch, and what’s planned next.',
    'path'        => '/roadmap',
    'image'       => '/images/og/roadmap.jpg',
    'imageAlt'    => 'VatSight roadmap and release notes.',
    'about'       => SITE_URL . '/#app',
    'breadcrumbs' => [['name' => 'Roadmap', 'path' => '/roadmap']],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="page-hero">
            <div class="section-inner">
                <?= breadcrumbs_html($crumbs) ?>
                <h1>Roadmap &amp; release notes</h1>
                <p class="page-hero-sub">VatSight is built in the open, one release at a time. Here’s everything that has shipped so far, and what’s coming in the next major update.</p>
            </div>
        </section>

        <section class="opensource roadmap-page">
            <div class="section-inner">
                <div class="roadmap">
                    <div class="roadmap-head">
                        <div>
                            <h2>Timeline</h2>
                            <p>Newest first: what’s planned next, the latest release, then everything shipped since the first map in May 2026.</p>
                        </div>
                        <?php if ($roadmap['updated']): ?>
                            <p class="roadmap-updated">Updated <time datetime="<?= e(date('Y-m-d', $roadmap['updated'])) ?>"><?= e(content_date($roadmap['updated'])) ?></time></p>
                        <?php endif; ?>
                    </div>
                    <?= roadmap_timeline(true) ?>
                </div>
            </div>
        </section>

        <section class="split-section split-section-plain">
            <div class="section-inner split split-even">
                <div class="split-copy prose">
                    <h2>Have an idea?</h2>
                    <p>Most of the roadmap started as a suggestion from someone on the network. Feature requests and bug reports are welcome as <a href="<?= e(GITHUB_URL) ?>/issues" target="_blank" rel="noopener">GitHub issues</a>, through the <a href="/contact">contact form</a>, or from <strong>Settings → Contact Us</strong> in the app.</p>
                </div>
                <div class="split-copy prose">
                    <h2>Try it before everyone else</h2>
                    <p>New versions go to TestFlight testers first. <a href="<?= e(NEWSLETTER_URL) ?>">Join the newsletter</a> and your welcome email includes an optional invite to the beta, along with a short note whenever a release lands.</p>
                </div>
            </div>
        </section>

        <?= download_panel() ?>
<?php require __DIR__ . '/partials/footer.php'; ?>
