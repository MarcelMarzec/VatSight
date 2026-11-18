<?php
require_once __DIR__ . '/partials/config.php';

// The no-JavaScript path: Formspree redirects back here on success.
$sent = isset($_GET['sent']);

$page = [
    'title'       => 'Contact VatSight: Bug Reports, Feedback & Sector Issues',
    'description' => 'Get in touch about VatSight: report a bug, suggest a feature, flag a VATSIM sector or ATC issue, or just say hello. Messages go straight to the developer.',
    'path'        => '/contact',
    'webPageType' => 'ContactPage',
    'breadcrumbs' => [['name' => 'Contact', 'path' => '/contact']],
    // reCAPTCHA and Formspree are the only third parties, and only on this page.
    'csp'         => [
        'script-src'  => ["'self'", 'https://www.google.com/recaptcha/', 'https://www.gstatic.com/recaptcha/'],
        'frame-src'   => ['https://www.google.com/recaptcha/', 'https://recaptcha.google.com/recaptcha/'],
        'connect-src' => ["'self'", 'https://formspree.io'],
        'form-action' => ['https://formspree.io'],
        'style-src'   => ["'unsafe-inline'"],
        'img-src'     => ['https://www.gstatic.com'],
    ],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="page-hero">
            <div class="section-inner">
                <?= breadcrumbs_html($crumbs) ?>
                <h1>Get in touch</h1>
                <p class="page-hero-sub">Bug reports, feature ideas, a sector that looks wrong, or anything else about VatSight. This reaches me directly, and I read everything.</p>
            </div>
        </section>

        <section class="contact-section">
            <div class="section-inner contact-layout">
                <div>
                    <div id="form-status" aria-live="polite">
                        <div class="alert alert-success" role="status"<?= $sent ? '' : ' hidden' ?>>
                            <strong>Message sent.</strong>
                            Thanks, I'll get back to you at the address you gave.
                        </div>
                        <div class="alert alert-error" role="alert" hidden>
                            <strong>That didn't send.</strong>
                            Something went wrong on the way to my inbox. Try again, or <a href="mailto:<?= e(CONTACT_EMAIL) ?>">email me</a> instead.
                        </div>
                    </div>

                    <form class="form contact-form" action="<?= e(FORMSPREE_URL) ?>" method="POST">
                        <div class="field">
                            <label for="name">Your name</label>
                            <input type="text" id="name" name="name" autocomplete="name" required>
                        </div>

                        <div class="field">
                            <label for="email">Email address</label>
                            <input type="email" id="email" name="email" autocomplete="email" required>
                            <p class="field-hint">So I have somewhere to reply to.</p>
                        </div>

                        <div class="field">
                            <label for="subject">Subject</label>
                            <input type="text" id="subject" name="subject" required>
                        </div>

                        <div class="field">
                            <label for="message">Message</label>
                            <textarea id="message" name="message" rows="7" required></textarea>
                            <p class="field-hint">For a bug, say what you expected and what happened. For a sector issue, include the controller’s callsign, e.g. <code>EGTT_W_CTR</code>.</p>
                        </div>

                        <!-- Honeypot: hidden from people, filled in by bots, dropped by Formspree. -->
                        <div class="hp" aria-hidden="true">
                            <label for="_gotcha">Leave this field empty</label>
                            <input type="text" id="_gotcha" name="_gotcha" tabindex="-1" autocomplete="off">
                        </div>

                        <input type="hidden" name="_subject" value="New message from vatsight.com">
                        <input type="hidden" name="_next" value="<?= e(SITE_URL) ?>/contact?sent=1">

                        <div class="field field-captcha">
                            <!-- data-theme here is reCAPTCHA's own attribute: it only styles Google's widget. -->
                            <div class="g-recaptcha"
                                 data-sitekey="<?= e(RECAPTCHA_SITE_KEY) ?>"
                                 data-action="contact"
                                 data-theme="dark"></div>
                            <p class="field-error" id="captcha-error" hidden>
                                Tick the box above so I know you're not a robot.
                            </p>
                        </div>

                        <button class="btn-primary" type="submit">
                            Send message <?= icon('arrow') ?>
                        </button>

                        <p class="field-hint form-footnote">
                            The form is handled by <a href="https://formspree.io" target="_blank" rel="noopener">Formspree</a> and protected by
                            Google reCAPTCHA, so Google sees your IP address and some browser data and sets a
                            cookie. Google's <a href="https://policies.google.com/privacy" target="_blank" rel="noopener">privacy policy</a> and
                            <a href="https://policies.google.com/terms" target="_blank" rel="noopener">terms</a> apply, and our
                            <a href="/privacy_policy#contact-form">privacy policy</a> explains the rest.
                        </p>
                    </form>
                </div>

                <aside class="contact-aside">
                    <h2>Other ways to reach me</h2>
                    <ul class="contact-links">
                        <li>
                            <a href="<?= e(GITHUB_URL) ?>/issues" target="_blank" rel="noopener">
                                <?= icon('github') ?>
                                <span><strong>GitHub issues</strong>The fastest route for bugs and feature requests, and you can follow the fix.</span>
                            </a>
                        </li>
                        <li>
                            <div class="contact-link-static">
                                <?= icon('bug') ?>
                                <span><strong>From the app</strong>Settings → Contact Us opens a pre-filled email, with a field for the ATC position or sector you’re reporting.</span>
                            </div>
                        </li>
                        <li>
                            <a href="https://github.com/lennycolton/vatglasses-data" target="_blank" rel="noopener">
                                <?= icon('layers') ?>
                                <span><strong>Sector boundaries</strong>Wrong airspace shapes or ownership come from VATGlasses; corrections go to their data repository.</span>
                            </a>
                        </li>
                        <li>
                            <a href="mailto:<?= e(CONTACT_EMAIL) ?>">
                                <?= icon('mail') ?>
                                <span><strong>Email</strong><?= e(CONTACT_EMAIL) ?></span>
                            </a>
                        </li>
                    </ul>
                </aside>
            </div>
        </section>

        <script src="https://www.google.com/recaptcha/enterprise.js" async defer></script>
        <script src="<?= e(asset('/js/contact.js')) ?>" defer></script>
<?php require __DIR__ . '/partials/footer.php'; ?>
