<?php
// Error page for 404 / 403 / 500 etc. Served by ErrorDocument in .htaccess, so the
// original status code is kept (search engines see a real 404, not a redirect).
$code = (int)($_SERVER['REDIRECT_STATUS'] ?? 404);
if ($code < 400) { $code = 404; } // visited directly, e.g. /error
http_response_code($code);
header("Cache-Control: no-store");
header("Content-Security-Policy: default-src 'self'; script-src 'none'; style-src 'self' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src 'self' data:; form-action 'self'; frame-ancestors 'self'; base-uri 'self'; object-src 'none'; upgrade-insecure-requests");

$messages = [
    403 => ['Access denied', "You don't have permission to view this page."],
    404 => ['Page not found', "We couldn't find that page. It may have moved, or the link might be out of date."],
    410 => ['Page removed', 'This page has been permanently removed.'],
    500 => ['Something went wrong', "The server hit a problem loading this page. Please try again in a moment."],
    503 => ['Down for maintenance', "VatSight is briefly offline for maintenance. Please check back shortly."],
];
[$heading, $message] = $messages[$code] ?? ['Something went wrong', "That page couldn't be loaded."];
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <title><?= htmlspecialchars($heading) ?> — VatSight</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="robots" content="noindex, follow" />
    <meta name="theme-color" content="#090909" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" type="text/css" href="/style/style.css?v=20261007"/>
    <link rel="icon" type="image/png" href="/images/favicon/favicon-96x96.png?v=20260509" sizes="96x96" />
    <link rel="icon" type="image/svg+xml" href="/images/favicon/favicon.svg?v=20260509" />
    <link rel="shortcut icon" href="/images/favicon/favicon.ico?v=20260509" />
    <link rel="apple-touch-icon" sizes="180x180" href="/images/favicon/apple-touch-icon.png?v=20260509" />
</head>

<body>

    <a class="skip-link" href="#main-content">Skip to main content</a>

    <?php include __DIR__ . '/partials/header.php'; ?>

    <main id="main-content">
        <section class="final-cta error-page">
            <div class="section-inner">
                <span class="error-code" aria-hidden="true"><?= $code ?></span>
                <span class="cta-eyebrow">Error <?= $code ?></span>
                <h1><?= htmlspecialchars($heading) ?></h1>
                <p><?= htmlspecialchars($message) ?></p>
                <div class="hero-actions">
                    <a class="btn-primary" href="/">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/></svg>
                        Back to home
                    </a>
                    <a class="btn-secondary" href="/#newsletter">Join the open beta</a>
                </div>
                <ul class="error-links">
                    <li><a href="/#features">Features</a></li>
                    <li><a href="/#screenshots">Screenshots</a></li>
                    <li><a href="/#faq">FAQ</a></li>
                    <li><a href="/privacy_policy">Privacy Policy</a></li>
                </ul>
            </div>
        </section>
    </main>

    <?php include __DIR__ . '/partials/footer.php'; ?>

</body>

</html>
