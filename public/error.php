<?php
// Error page for 404 / 403 / 500 etc. Served by ErrorDocument in .htaccess, so the
// original status code is kept (search engines see a real 404, not a redirect).
// Also required by guides.php for unknown guides, possibly from inside a function,
// hence the globals.
require_once __DIR__ . '/partials/config.php';
global $nav, $footerGroups, $authors;

$code = (int) ($_SERVER['REDIRECT_STATUS'] ?? 404);
if ($code < 400) {
    $code = 404; // visited directly, e.g. /error
}
http_response_code($code);

$messages = [
    403 => ['Access denied', "You don't have permission to view this page."],
    404 => ['Page not found', "We couldn't find that page. It may have moved, or the link might be out of date."],
    410 => ['Page removed', 'This page has been permanently removed.'],
    500 => ['Something went wrong', 'The server hit a problem loading this page. Please try again in a moment.'],
    503 => ['Down for maintenance', 'VatSight is briefly offline for maintenance. Please check back shortly.'],
];
[$heading, $message] = $messages[$code] ?? ['Something went wrong', "That page couldn't be loaded."];

$page = [
    'title'       => $heading . ' — VatSight',
    'description' => $message,
    'path'        => '/error',
    'noindex'     => true,
    'cache'       => 'no-store',
];
require __DIR__ . '/partials/head.php';
?>
        <section class="final-cta error-page">
            <div class="section-inner">
                <span class="error-code" aria-hidden="true"><?= $code ?></span>
                <h1><?= e($heading) ?></h1>
                <p><?= e($message) ?></p>
                <div class="hero-actions">
                    <a class="btn-primary" href="/">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/></svg>
                        Back to home
                    </a>
                    <a class="btn-secondary" href="/guides"><?= icon('book') ?>Read the guides</a>
                </div>
                <ul class="error-links">
                    <li><a href="/vatsim-map">VATSIM live map</a></li>
                    <li><a href="/vatglasses">VATGlasses sectors</a></li>
                    <li><a href="/vatsim-tracker">VATSIM tracker</a></li>
                    <li><a href="/#faq">FAQ</a></li>
                    <li><a href="/contact">Contact</a></li>
                </ul>
            </div>
        </section>
<?php require __DIR__ . '/partials/footer.php'; ?>
