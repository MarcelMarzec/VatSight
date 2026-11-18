<?php
require_once __DIR__ . '/partials/config.php';

$faqs = [
    [
        'q' => 'Is there a VATSIM map app for iPhone?',
        'a' => 'Yes. VatSight is a native VATSIM map for iPhone and iPad. It plots every pilot and controller on the network, draws the airspace each controller is working, and is free on the <a class="link-text" href="' . e(APP_STORE_URL) . '" target="_blank" rel="noopener">App Store</a>.',
    ],
    [
        'q' => 'How live is the VATSIM map?',
        'a' => 'VATSIM publishes a fresh snapshot of the whole network every 15 seconds, and VatSight fetches it every 15 seconds by default, so positions are never more than a few seconds behind what VATSIM itself knows. You can slow it to every 30 seconds or every minute in Settings.',
    ],
    [
        'q' => 'Why can’t I see aircraft parked at airports?',
        'a' => 'Aircraft moving slower than 40 knots count as on the ground, and they appear once you zoom in close to an airport. Hiding them further out keeps big hubs readable. Their numbers are always in the airport’s traffic counts.',
    ],
    [
        'q' => 'Does the map show prefiled flight plans?',
        'a' => 'Prefiled flights have no position yet, so they aren’t drawn on the map, but they are counted in each airport’s departures and arrivals, and the airport sheet lists them.',
    ],
    [
        'q' => 'Can I see ATC sectors that nobody is controlling?',
        'a' => 'Yes. Turn on <strong>Inactive sectors</strong> in the layer menu to draw every VATGlasses sector outline, online or not. It is a quick way to see how a country’s airspace is split up. More on that on the <a class="link-text" href="/vatglasses">VATGlasses page</a>.',
    ],
    [
        'q' => 'Does VatSight work on iPad?',
        'a' => 'Yes. The same app runs on iPhone and iPad with iPadOS 26 or later, and the bigger screen shows more of the network at once.',
    ],
];

$page = [
    'title'       => 'VATSIM Live Map & Radar for iPhone and iPad | VatSight',
    'description' => 'Every VATSIM pilot and controller on a live map, with VATGlasses ATC sectors, flight plans and airport traffic. Free for iPhone and iPad, updated every 15 s.',
    'path'        => '/vatsim-map',
    'about'       => SITE_URL . '/#app',
    'image'       => '/images/og/vatsim-map.jpg',
    'imageAlt'    => 'VatSight: the VATSIM live map on your iPhone, with every pilot and controller on the network.',
    'breadcrumbs' => [['name' => 'VATSIM live map', 'path' => '/vatsim-map']],
    'schema'      => [schema_app_node(), schema_faq_node($faqs, '/vatsim-map')],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="hero page-hero-split">
            <div class="hero-inner">
                <div class="hero-copy">
                    <?= breadcrumbs_html($crumbs) ?>
                    <h1>VATSIM live map &amp; radar, on your iPhone</h1>
                    <p class="hero-sub">VatSight puts the whole VATSIM network in your pocket: every pilot, every controller and the exact airspace they’re working, on a fast native map that updates every 15 seconds.</p>
                    <div class="hero-actions">
                        <?= app_store_badge() ?>
                        <a class="btn-secondary" href="#on-the-map">What’s on the map <?= icon('arrow') ?></a>
                    </div>
                    <ul class="hero-meta">
                        <li>Free</li>
                        <li>No VATSIM login</li>
                        <li>iPhone &amp; iPad</li>
                    </ul>
                </div>
                <div class="hero-visual">
                    <?= phone_shot('uk-overview', ['eager' => true, 'caption' => '', 'class' => 'phone-hero']) ?>
                </div>
            </div>
        </section>

        <section class="features" id="on-the-map">
            <div class="section-inner">
                <div class="section-head">
                    <h2>What’s on the VATSIM map</h2>
                    <p>Four layers, each one tappable. Everything comes from live VATSIM and VATGlasses data, not a delayed copy.</p>
                </div>
                <div class="feature-grid feature-grid-2">
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('radar') ?></div>
                        <h3>Pilots</h3>
                        <p>Every connected pilot is drawn at their reported position, rotated to their heading. Callsigns appear as you zoom in, and aircraft on the ground (under 40 knots) appear once you’re close to an airport, so busy hubs stay readable from further out.</p>
                        <ul class="legend">
                            <li><span class="swatch swatch-gold"></span>You, once your VATSIM CID is set</li>
                            <li><span class="swatch swatch-green"></span>Friends you’ve added</li>
                            <li><span class="swatch swatch-red"></span>The aircraft you’ve tapped</li>
                        </ul>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('layers') ?></div>
                        <h3>ATC sectors</h3>
                        <p>Each online controller’s airspace is filled in using <a class="link-text" href="/vatglasses">VATGlasses</a> boundaries, in the colour VATGlasses gives that position. Zoomed out you see a dot, then the callsign, then the callsign and frequency together as you zoom in.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('pin') ?></div>
                        <h3>Airports</h3>
                        <p>Airports with ATC online, or with a flight planned in or out, are highlighted. Small badges show which ground services are open:</p>
                        <ul class="badge-key">
                            <li><span class="svc svc-t">T</span>Tower</li>
                            <li><span class="svc svc-g">G</span>Ground</li>
                            <li><span class="svc svc-d">D</span>Delivery</li>
                            <li><span class="svc svc-a">A</span>ATIS</li>
                        </ul>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('route') ?></div>
                        <h3>Routes</h3>
                        <p>Tap an aircraft and VatSight draws great-circle lines to its departure airport in red and its destination in green, with the alternate dashed. Tap an airport instead and it draws a line to every flight in the air heading to or from it.</p>
                    </article>
                </div>
            </div>
        </section>

        <section class="split-section">
            <div class="section-inner split">
                <div class="split-copy prose">
                    <h2>How live is the VATSIM map?</h2>
                    <p>VATSIM publishes a snapshot of the entire network, every pilot, controller, ATIS and flight plan, through its public <a href="https://vatsim.dev/api/data-api/" target="_blank" rel="noopener">Data API</a>. The snapshot is refreshed every 15 seconds, and VatSight downloads it on the same 15-second cycle.</p>
                    <ul>
                        <li><strong>Choose your refresh rate.</strong> 15 seconds, 30 seconds or 1 minute, in Settings. Slower uses less mobile data.</li>
                        <li><strong>Nothing runs in the background.</strong> Updates pause when you leave the app and catch up the moment you come back.</li>
                        <li><strong>You’ll know if it’s stale.</strong> If two refreshes in a row are missed, a banner at the top of the map tells you, and shows whether you’re offline.</li>
                        <li><strong>Sectors load instantly.</strong> VATGlasses airspace is stored on your phone after the first download and only re-checked for updates once a week.</li>
                    </ul>
                </div>
                <div class="split-visual">
                    <?= phone_shot('zoom-details') ?>
                </div>
            </div>
        </section>

        <section class="features">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Make the map yours</h2>
                    <p>Everything is a toggle away in the layer menu or Settings, and VatSight remembers your choices and where you left the map.</p>
                </div>
                <div class="feature-grid">
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('layers') ?></div>
                        <h3>Layers</h3>
                        <p>Show or hide pilots, sectors and airports on their own. Turn on every airport, not just the busy ones, or every sector outline, not just the online ones.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('merge') ?></div>
                        <h3>Merge sectors</h3>
                        <p>One controller often works a dozen VATGlasses sectors. Merge them into a single outline per controller to see who owns what at a glance.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('altitude') ?></div>
                        <h3>Altitude filter</h3>
                        <p>Slide from the ground to FL600 and only the sectors covering that level stay on the map. Tap an aircraft and the slider jumps to its altitude.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('palette') ?></div>
                        <h3>Map styles</h3>
                        <p>Night, Dark and Day map styles, or let VatSight follow your iPhone’s light or dark mode. The app theme can follow the map or be set on its own.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('radar') ?></div>
                        <h3>Icon sizes</h3>
                        <p>Make aircraft and airport icons bigger or smaller, so the map works for you on a small iPhone or a 13-inch iPad.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('shield') ?></div>
                        <h3>Accessibility</h3>
                        <p>Haptic feedback can be turned off, and VatSight respects iOS Reduce Motion by toning down animations and haptics automatically.</p>
                    </article>
                </div>
            </div>
        </section>

        <section class="showcase">
            <div class="section-inner">
                <div class="section-head">
                    <h2>The VATSIM network, the way you like it</h2>
                    <p>Dark or light, every sector or just the ones that matter to you.</p>
                </div>
                <div class="showcase-row">
                    <?php foreach (['light-mode', 'blended-sectors', 'show-inactive-sectors', 'merged-sectors', 'track-overlay'] as $shot): ?>
                        <?= phone_shot($shot, ['sizes' => '225px']) ?>
                    <?php endforeach; ?>
                </div>
            </div>
        </section>

        <section class="split-section">
            <div class="section-inner split split-reverse">
                <div class="split-copy prose">
                    <h2>Why use an app instead of a web map?</h2>
                    <p>Browser-based VATSIM maps are great at a desk. On a phone, a native app is simply nicer to use:</p>
                    <ul>
                        <li><strong>Smooth on small screens.</strong> Mapbox’s native renderer handles thousands of aircraft and sector outlines without breaking a sweat.</li>
                        <li><strong>Built for touch.</strong> Tap anything for a details sheet, swipe it away, and search with the keyboard you already know.</li>
                        <li><strong>Remembers you.</strong> Your CID, friends, layers and last map position are saved on your device. No account, no sign-in.</li>
                        <li><strong>Private.</strong> No analytics and no tracking. Ads are off unless you choose to switch them on to support development.</li>
                    </ul>
                    <p>New to the network? Start with <a href="/guides/vatsim-atc-positions-explained">VATSIM ATC positions explained</a>.</p>
                </div>
                <div class="split-visual">
                    <?= phone_shot('pilot-details') ?>
                </div>
            </div>
        </section>

        <section class="faq" id="faq">
            <div class="section-inner">
                <div class="section-head">
                    <h2>VATSIM map questions</h2>
                </div>
                <?= faq_list($faqs) ?>
            </div>
        </section>

        <section class="related">
            <div class="section-inner">
                <div class="section-head">
                    <h2>More from VatSight</h2>
                </div>
                <?= related_pages('/vatsim-map') ?>
            </div>
        </section>

        <?= download_panel('See the VATSIM network live', 'Free on the App Store for iPhone and iPad. Open it and the whole network is there, no sign-in needed.') ?>
<?php require __DIR__ . '/partials/footer.php'; ?>
