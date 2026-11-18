<?php
require_once __DIR__ . '/partials/config.php';
require_once __DIR__ . '/partials/markdown.php';
require_once __DIR__ . '/partials/content.php';
require_once __DIR__ . '/partials/roadmap.php';

// One list feeds both the visible FAQ and its structured data.
$faqs = [
    [
        'q' => 'What is VatSight?',
        'a' => 'VatSight is a free VATSIM app for iPhone and iPad. It shows every pilot and controller on the VATSIM network on a live map, draws the exact <a class="link-text" href="/vatglasses">VATGlasses ATC sectors</a> each controller is working, and lets you check the traffic, ATIS and METAR at any airport.',
    ],
    [
        'q' => 'Is there a VATSIM app for iPhone?',
        'a' => 'Yes. VatSight is a native VATSIM app for iOS that works as a <a class="link-text" href="/vatsim-map">live VATSIM map</a> and <a class="link-text" href="/vatsim-tracker">flight tracker</a> on your iPhone and iPad. Find any pilot by callsign, keep track of friends by their CID, see which ATC positions are online and the airspace they cover, and check activity at any airport. <a class="link-text" href="' . e(APP_STORE_URL) . '" target="_blank" rel="noopener">Download it free on the App Store</a>.',
    ],
    [
        'q' => 'Is VatSight free to use?',
        'a' => 'Yes. VatSight is completely free, with no account required, and every feature is included for everyone. If you want to support development, you can turn on optional ads in the app. They are off by default and never lock or unlock any feature.',
    ],
    [
        'q' => 'How often does the VATSIM map update?',
        'a' => 'Every 15 seconds by default, which matches how often VATSIM publishes its network data. You can switch to every 30 seconds or every minute in Settings to save data. Updates pause while the app is in the background, and a banner tells you if the data has gone stale.',
    ],
    [
        'q' => 'What is VATGlasses and how does VatSight use it?',
        'a' => 'VATGlasses is an open, community-maintained dataset of VATSIM ATC sector boundaries, kept up to date by vACC staff. VatSight downloads it, matches each online controller to the sectors they own, and draws them live on the map. You can merge each controller’s sectors into one outline or filter them by altitude. Read <a class="link-text" href="/guides/what-is-vatglasses">What is VATGlasses?</a> for the full story.',
    ],
    [
        'q' => 'Can I track my friends on VATSIM?',
        'a' => 'Yes. Add your friends’ VATSIM CIDs in Settings and their aircraft, ATC positions and the airports they control are highlighted in green. Enter your own CID and you show up in gold. See <a class="link-text" href="/vatsim-tracker">VATSIM tracker</a> for how it works.',
    ],
    [
        'q' => 'Do I need a VATSIM account to use VatSight?',
        'a' => 'No. VatSight reads publicly available VATSIM network data, so you can view live traffic and ATC sectors without logging in or creating an account.',
    ],
    [
        'q' => 'Is VatSight available on Android or in a web browser?',
        'a' => 'Not at the moment. VatSight is built natively for iPhone and iPad and needs iOS 26 or iPadOS 26 or later.',
    ],
    [
        'q' => 'Is VatSight affiliated with VATSIM or VATGlasses?',
        'a' => 'No. VatSight is an independent project. It is not affiliated with or endorsed by VATSIM or VATGlasses, though it relies on their public data.',
    ],
    [
        'q' => 'Can I try new VatSight features early?',
        'a' => 'Yes. <a class="link-text" href="#newsletter">Sign up to the newsletter</a> and confirm your email address. Your welcome email includes an optional invite to the TestFlight beta, where you can try upcoming versions before they reach the App Store.',
    ],
];

$latestGuides = array_slice(guides_all(), 0, 3);

$page = [
    'title'       => 'VatSight — Free VATSIM Map & Tracker App for iPhone',
    'description' => 'VatSight is a free VATSIM app for iPhone and iPad: a live map of every pilot and controller, VATGlasses ATC sectors, airport traffic and friend tracking.',
    'path'        => '/',
    'about'       => SITE_URL . '/#app',
    'preload'     => [[
        'href'   => asset('/images/screenshots/uk-overview-750.webp'),
        'srcset' => asset('/images/screenshots/uk-overview-750.webp') . ' 750w, ' . asset('/images/screenshots/uk-overview.webp') . ' 1206w',
        'sizes'  => '(max-width: 600px) 62vw, 343px',
    ]],
    'schema'      => [schema_app_node(), schema_faq_node($faqs, '/')],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="hero" id="top">
            <div class="hero-inner">
                <div class="hero-copy">
                    <h1>The live VATSIM map for iPhone and iPad.</h1>
                    <p class="hero-sub">VatSight is a free VATSIM tracker and radar for your iPhone. See every pilot and controller on the network, the exact VATGlasses airspace each controller is working, and what’s happening at any airport, all on one clean map.</p>
                    <div class="hero-actions">
                        <?= app_store_badge() ?>
                        <a class="btn-secondary" href="/vatsim-map">See how it works <?= icon('arrow') ?></a>
                    </div>
                    <ul class="hero-meta">
                        <li>iPhone &amp; iPad</li>
                        <li>Free, no account needed</li>
                        <li>Updates every 15 seconds</li>
                        <li><a href="<?= e(GITHUB_URL) ?>" target="_blank" rel="noopener">Source on GitHub</a></li>
                    </ul>
                </div>
                <div class="hero-visual">
                    <?= phone_shot('uk-overview', ['eager' => true, 'caption' => '', 'class' => 'phone-hero']) ?>
                </div>
            </div>
        </section>

        <section class="features" id="features">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Everything you need on frequency</h2>
                    <p>The VATSIM app for iOS, built for controllers, pilots and spotters who live on the network.</p>
                </div>
                <div class="feature-grid">
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('radar') ?></div>
                        <h3>Live VATSIM map</h3>
                        <p>Every pilot and controller on the VATSIM network on a smooth, interactive map, refreshed every 15 seconds. Zoom in for callsigns, frequencies and aircraft on the ground.</p>
                        <a class="feature-link" href="/vatsim-map">Explore the live map <?= icon('arrow') ?></a>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('layers') ?></div>
                        <h3>VATGlasses ATC sectors</h3>
                        <p>The exact airspace each online controller is working, powered by VATGlasses. Merge each controller’s sectors into one outline, or filter them by altitude.</p>
                        <a class="feature-link" href="/vatglasses">How VATGlasses works <?= icon('arrow') ?></a>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('card') ?></div>
                        <h3>Full flight details</h3>
                        <p>Tap any aircraft for altitude, speed, heading and squawk, the full filed flight plan and its route, with lines drawn to the departure and arrival airports.</p>
                        <a class="feature-link" href="/vatsim-tracker">Track a flight <?= icon('arrow') ?></a>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('users') ?></div>
                        <h3>You and your friends</h3>
                        <p>Add your VATSIM CID to see yourself in gold, and your friends’ CIDs to see their flights, ATC positions and airports in green.</p>
                        <a class="feature-link" href="/vatsim-tracker#friends">Follow your friends <?= icon('arrow') ?></a>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('pin') ?></div>
                        <h3>Explore airports</h3>
                        <p>Online controllers, the latest ATIS and METAR, and every departure, arrival and aircraft on the ground, including prefiled flight plans.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('search') ?></div>
                        <h3>Powerful search</h3>
                        <p>Jump to any callsign, airport or controller in seconds. Filter ATC by facility and sort airports by traffic to find where the action is.</p>
                    </article>
                </div>
            </div>
        </section>

        <section class="showcase" id="screenshots">
            <div class="section-inner">
                <div class="section-head">
                    <h2>A closer look</h2>
                    <p>Dark mode, light mode, and full control over what the map shows you.</p>
                </div>
                <div class="showcase-row">
                    <?php foreach (array_keys(screenshots()) as $shot): ?>
                        <?= phone_shot($shot, ['sizes' => '225px']) ?>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>

        <?php if ($latestGuides): ?>
        <section class="home-guides" id="guides">
            <div class="section-inner">
                <div class="section-head section-head-row">
                    <div>
                        <h2>Learn the network</h2>
                        <p>Guides to VATSIM ATC, VATGlasses and following flights, from the developer of VatSight.</p>
                    </div>
                    <a class="btn-secondary" href="/guides">All guides <?= icon('arrow') ?></a>
                </div>
                <div class="guide-grid">
                    <?php foreach ($latestGuides as $guide): ?>
                        <article class="guide-card">
                            <a href="<?= e($guide['url']) ?>">
                                <span class="guide-card-body">
                                    <span class="guide-meta"><span><?= (int) $guide['minutes'] ?> min read</span></span>
                                    <span class="guide-card-title"><?= e($guide['title']) ?></span>
                                    <span class="guide-card-summary"><?= e($guide['summary']) ?></span>
                                    <span class="guide-card-more">Read the guide <?= icon('arrow') ?></span>
                                </span>
                            </a>
                        </article>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>
        <?php endif; ?>

        <section class="opensource" id="open-source">
            <div class="section-inner">
                <div class="opensource-card">
                    <div>
                        <h2>Built in the open</h2>
                        <p>VatSight’s source code has been on GitHub from day one. Read the code, file an issue, or send a pull request: the whole app is built with the community watching.</p>
                        <a class="btn-primary" href="<?= e(GITHUB_URL) ?>" target="_blank" rel="noopener"><?= icon('github') ?>Star on GitHub</a>
                    </div>
                    <ul class="opensource-list">
                        <li><?= icon('check') ?>View and scrutinise the entire codebase</li>
                        <li><?= icon('check') ?>Contribute fixes, features and improvements</li>
                        <li><?= icon('check') ?>No accounts and no analytics; ads only if you opt in</li>
                        <li><?= icon('check') ?>Free to use, not for resale as a competing app</li>
                    </ul>
                </div>

                <div class="roadmap roadmap-compact">
                    <div class="roadmap-head">
                        <div>
                            <h3>Roadmap</h3>
                            <p>Where VatSight is now, and what’s next.</p>
                        </div>
                        <a class="btn-secondary" href="/roadmap">Full roadmap <?= icon('arrow') ?></a>
                    </div>
                    <?= roadmap_timeline(false, ['current', 'planned']) ?>
                </div>
            </div>
        </section>

        <section class="credits" id="credits">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Credits &amp; data sources</h2>
                    <p>VatSight is built on public data from these open, community-run projects.</p>
                </div>
                <div class="credits-grid">
                    <div class="credits-card">
                        <div class="credits-icon"><?= icon('radar') ?></div>
                        <div>
                            <h3>VATSIM Data API</h3>
                            <p>Live pilot and controller positions, flight plans and ATIS text come straight from the public <a class="link-text" href="https://vatsim.dev/api/data-api/" target="_blank" rel="noopener">VATSIM Data API</a>, and METARs from <a class="link-text" href="https://metar.vatsim.net" target="_blank" rel="noopener">metar.vatsim.net</a>. VatSight is not affiliated with or endorsed by VATSIM.</p>
                        </div>
                    </div>
                    <div class="credits-card">
                        <div class="credits-icon"><?= icon('layers') ?></div>
                        <div>
                            <h3>VATGlasses</h3>
                            <p>ATC sector boundaries come from <a class="link-text" href="https://vatglasses.uk" target="_blank" rel="noopener">VATGlasses</a>, an open, community-maintained airspace dataset kept accurate by vACC staff across the VATSIM network, via their <a class="link-text" href="https://github.com/lennycolton/vatglasses-data" target="_blank" rel="noopener">public data repository</a> under CC BY-NC-SA 4.0. VatSight is not affiliated with or endorsed by VATGlasses.</p>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section class="faq" id="faq">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Frequently asked questions</h2>
                    <p>Everything you might want to know about VatSight, VATSIM and VATGlasses on iPhone.</p>
                </div>
                <?= faq_list($faqs) ?>
            </div>
        </section>

        <section class="final-cta" id="newsletter">
            <div class="section-inner">
                <h2>Stay in the loop</h2>
                <p>Get the VatSight newsletter for release news and major updates. A few emails a year, never spam. Want to try new features early? Your welcome email includes an optional invite to the TestFlight beta.</p>
                <!-- Newsletter sign-up: posts straight to phpList (public/phplist). Keep list[2] and id=1 in sync with the phpList list and subscribe page IDs. -->
                <form class="signup-form" action="/phplist/?p=subscribe&amp;id=1" method="post">
                    <input type="hidden" name="list[2]" value="signup">
                    <input type="hidden" name="htmlemail" value="1">
                    <div class="signup-hp" aria-hidden="true">
                        <label>Leave this field empty <input type="text" name="VerificationCodeX" value="" tabindex="-1" autocomplete="off"></label>
                    </div>
                    <div class="signup-row">
                        <label for="signup-email" class="sr-only">Email address</label>
                        <input id="signup-email" type="email" name="email" placeholder="you@example.com" autocomplete="email" maxlength="254" required>
                        <button type="submit" name="subscribe" value="Subscribe">Subscribe</button>
                    </div>
                    <p class="signup-legal">We'll email you a link to confirm your subscription. Unsubscribe any time with one click. See our <a href="/privacy_policy#newsletter">Privacy Policy</a>.</p>
                </form>
                <div class="hero-actions">
                    <?= app_store_badge() ?>
                    <a class="btn-secondary" href="<?= e(GITHUB_URL) ?>" target="_blank" rel="noopener"><?= icon('github') ?>Follow on GitHub</a>
                    <a class="btn-secondary" href="/contact"><?= icon('mail') ?>Get in touch</a>
                </div>
            </div>
        </section>
<?php require __DIR__ . '/partials/footer.php'; ?>
