<?php
require_once __DIR__ . '/partials/config.php';

$faqs = [
    [
        'q' => 'How do I track someone on VATSIM?',
        'a' => 'In VatSight, add their VATSIM CID under Settings → Friends. Whenever they connect, as a pilot or a controller, they are highlighted in green on the map and listed as online in your Friends list, where one tap takes you to them. The guide <a class="link-text" href="/guides/track-friends-on-vatsim">How to track your friends on VATSIM</a> walks through it.',
    ],
    [
        'q' => 'Can I search for a pilot by CID?',
        'a' => 'Search looks at callsigns, pilot names and departure or arrival airports. To keep an eye on a particular CID, add it as a friend instead: it then shows in your Friends list every time that person is online, whatever callsign they use.',
    ],
    [
        'q' => 'Where do I find my VATSIM CID?',
        'a' => 'Your CID is the number VATSIM gave you when you registered. It is shown when you sign in at my.vatsim.net, and in VatSight it appears in brackets after your name on your own flight or ATC sheet.',
    ],
    [
        'q' => 'Will VatSight notify me when a friend logs on?',
        'a' => 'Not yet. Push notifications are planned for version 1.1, alongside better flight following. See the <a class="link-text" href="/roadmap">roadmap</a>.',
    ],
    [
        'q' => 'Is my friends list stored online?',
        'a' => 'No. Your CID and friends list are stored only on your device. VatSight has no accounts and no server of its own, so nobody else can see who you follow.',
    ],
    [
        'q' => 'Can I track my own VATSIM flight?',
        'a' => 'Yes. Enter your CID in Settings → Friends and your aircraft shows in gold. While you are connected, a locate button appears on the map that flies straight to your aircraft, or to your airport or sector when you are controlling.',
    ],
];

$page = [
    'title'       => 'VATSIM Tracker App: Follow Flights & Friends | VatSight',
    'description' => 'Track any VATSIM flight by callsign, see its flight plan and route, and spot your friends on the map. A free VATSIM tracker for iPhone and iPad.',
    'path'        => '/vatsim-tracker',
    'image'       => '/images/og/vatsim-tracker.jpg',
    'imageAlt'    => 'VatSight: track any VATSIM flight or friend on your iPhone.',
    'about'       => SITE_URL . '/#app',
    'breadcrumbs' => [['name' => 'VATSIM tracker', 'path' => '/vatsim-tracker']],
    'schema'      => [schema_app_node(), schema_faq_node($faqs, '/vatsim-tracker')],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="hero page-hero-split">
            <div class="hero-inner">
                <div class="hero-copy">
                    <?= breadcrumbs_html($crumbs) ?>
                    <h1>Track any VATSIM flight, friend or controller</h1>
                    <p class="hero-sub">VatSight is a free VATSIM tracker for iPhone and iPad. Find any flight in seconds, see its full flight plan and route, follow your friends across the network, and know exactly who is working the airport you’re flying into.</p>
                    <div class="hero-actions">
                        <?= app_store_badge() ?>
                        <a class="btn-secondary" href="#friends">Follow your friends <?= icon('arrow') ?></a>
                    </div>
                    <ul class="hero-meta">
                        <li>Pilots, ATC &amp; airports</li>
                        <li>No account</li>
                        <li>Free</li>
                    </ul>
                </div>
                <div class="hero-visual">
                    <?= phone_shot('pilot-details', ['eager' => true, 'caption' => '', 'class' => 'phone-hero']) ?>
                </div>
            </div>
        </section>

        <section class="features">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Find any flight in seconds</h2>
                    <p>One search box for the whole network, split into Pilots, ATC and Airports. Tap a result and the map flies straight to it.</p>
                </div>
                <div class="feature-grid">
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('radar') ?></div>
                        <h3>Pilots</h3>
                        <p>Search by callsign, pilot name, or departure or arrival airport. Type <code>EGLL</code> and you get every flight in or out of Heathrow.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('tower') ?></div>
                        <h3>ATC</h3>
                        <p>Search controllers by callsign, name or frequency, and filter by facility: Delivery, Ground, Tower, Approach, Centre or FSS. Observers are hidden unless you want them.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('pin') ?></div>
                        <h3>Airports</h3>
                        <p>Find an airport by ICAO code, or sort them all by total pilots, controllers, departures, arrivals or aircraft on the ground to see where the action is.</p>
                    </article>
                </div>
            </div>
        </section>

        <section class="split-section">
            <div class="section-inner split">
                <div class="split-copy prose">
                    <h2>Everything about the flight</h2>
                    <p>Tap any aircraft, on the map or in search, and its details slide up while the map stays live behind them:</p>
                    <ul>
                        <li><strong>Live state:</strong> altitude, ground speed, heading and squawk.</li>
                        <li><strong>The flight plan:</strong> IFR or VFR, departure, arrival and alternate with airport names, aircraft type and equipment, route and remarks.</li>
                        <li><strong>Timings:</strong> logon time, planned departure time, en-route time and fuel on board.</li>
                        <li><strong>On the map:</strong> great-circle lines to the departure in red and the arrival in green, with the alternate dashed.</li>
                        <li><strong>Their airspace:</strong> with the altitude filter on, the slider follows the aircraft’s level, so you only see the sectors it is flying through.</li>
                    </ul>
                </div>
                <div class="split-visual">
                    <?= phone_shot('track-overlay') ?>
                </div>
            </div>
        </section>

        <section class="split-section" id="friends">
            <div class="section-inner split split-reverse">
                <div class="split-copy prose">
                    <h2>Follow your friends on VATSIM</h2>
                    <p>Add the VATSIM CIDs of the people you fly or control with in <strong>Settings → Friends</strong>. From then on:</p>
                    <ul>
                        <li><strong>They stand out.</strong> Your friends’ aircraft, the labels of the sectors they control and the airports they’re working are drawn in green.</li>
                        <li><strong>You know who’s online.</strong> The Friends list shows each friend as flying, controlling or offline, with their callsign, route or frequency and how long they’ve been connected.</li>
                        <li><strong>One tap to find them.</strong> Tap an online friend and the map flies straight to them.</li>
                        <li><strong>Add people as you go.</strong> Tap the star on any pilot’s details, or swipe right on a controller in an airport or sector sheet.</li>
                    </ul>
                    <p>Add your own CID too: your aircraft turns gold, and a locate button takes you straight to yourself, whether you’re flying or controlling. Everything stays on your device.</p>
                    <p>Step by step: <a href="/guides/track-friends-on-vatsim">How to track your friends on VATSIM</a>.</p>
                </div>
                <div class="split-visual">
                    <?= phone_shot('uk-overview') ?>
                </div>
            </div>
        </section>

        <section class="features">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Know who’s working your airport</h2>
                    <p>Tap any airport for a live picture of what’s happening there.</p>
                </div>
                <div class="feature-grid">
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('tower') ?></div>
                        <h3>Online controllers</h3>
                        <p>Everyone providing a service at the airport, from Delivery up, including approach and centre controllers covering it top-down, each with their frequency.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('card') ?></div>
                        <h3>ATIS and METAR</h3>
                        <p>The latest ATIS broadcast as text, and the current METAR from VATSIM’s weather service, so you know the runway and weather before you call.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon"><?= icon('route') ?></div>
                        <h3>Traffic</h3>
                        <p>Departures, arrivals and aircraft on the ground, with prefiled flights counted too. Tap any flight to jump to it on the map.</p>
                    </article>
                </div>
            </div>
        </section>

        <section class="faq" id="faq">
            <div class="section-inner">
                <div class="section-head">
                    <h2>VATSIM tracking questions</h2>
                </div>
                <?= faq_list($faqs) ?>
            </div>
        </section>

        <section class="related">
            <div class="section-inner">
                <div class="section-head">
                    <h2>More from VatSight</h2>
                </div>
                <?= related_pages('/vatsim-tracker') ?>
            </div>
        </section>

        <?= download_panel('Start tracking on VATSIM', 'Free on the App Store for iPhone and iPad. Add your CID and your friends in under a minute.') ?>
<?php require __DIR__ . '/partials/footer.php'; ?>
