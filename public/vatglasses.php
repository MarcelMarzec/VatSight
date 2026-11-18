<?php
require_once __DIR__ . '/partials/config.php';

$faqs = [
    [
        'q' => 'What is VATGlasses?',
        'a' => 'VATGlasses is an open, community-maintained map of VATSIM airspace. Volunteers from each vACC describe their sectors, the ATC positions that can own them, and the order in which ownership passes down when positions are offline. The data is public on <a class="link-text" href="https://github.com/lennycolton/vatglasses-data" target="_blank" rel="noopener">GitHub</a> under CC BY-NC-SA 4.0. Our guide <a class="link-text" href="/guides/what-is-vatglasses">What is VATGlasses?</a> goes into more detail.',
    ],
    [
        'q' => 'Is there a VATGlasses app for iPhone?',
        'a' => 'VATGlasses itself is a website. VatSight is a free iPhone and iPad app that uses the VATGlasses dataset to draw live VATSIM ATC sectors on a native map, alongside every pilot on the network. It is an independent project, not made by the VATGlasses team.',
    ],
    [
        'q' => 'Why is a controller online but no sector is shown?',
        'a' => 'Either their position isn’t in VATGlasses yet, or their callsign or frequency doesn’t match what VATGlasses expects (for example, a one-off event callsign). Approach and departure controllers without sector data still get a 15 nm circle around their airport. Everything else is listed under Settings → Sector Maintainers, so vACC staff can spot gaps.',
    ],
    [
        'q' => 'Why does a sector show a different controller than I expected?',
        'a' => 'That is top-down coverage at work. When the position that normally owns a sector is offline, VATGlasses passes it to the next position in its ownership list, often the centre controller above. VatSight follows the same order, so the colour and label show who is actually responsible right now.',
    ],
    [
        'q' => 'How up to date is the sector data?',
        'a' => 'VatSight stores the VATGlasses data on your phone, so sectors appear instantly. Once a week it checks GitHub for a newer version and downloads it if there is one. You can force a fresh download at any time in Settings → VATGlasses Sector Data.',
    ],
    [
        'q' => 'The sector data is wrong. Who do I tell?',
        'a' => 'Boundaries and ownership come from VATGlasses, which is maintained by vACC staff, so corrections belong on the <a class="link-text" href="https://github.com/lennycolton/vatglasses-data" target="_blank" rel="noopener">vatglasses-data repository</a>. If the data looks right but VatSight draws it wrong, <a class="link-text" href="/contact">tell me</a> and I’ll fix it.',
    ],
];

$page = [
    'title'       => 'VATGlasses on iPhone: Live VATSIM ATC Sector Map | VatSight',
    'description' => 'VatSight brings VATGlasses to iPhone and iPad: see which VATSIM ATC sectors are online, merge them, filter by altitude and tap for controller details.',
    'path'        => '/vatglasses',
    'image'       => '/images/og/vatglasses.jpg',
    'imageAlt'    => 'VatSight: VATGlasses ATC sectors, live on your iPhone.',
    'about'       => SITE_URL . '/#app',
    'breadcrumbs' => [['name' => 'VATGlasses sectors', 'path' => '/vatglasses']],
    'schema'      => [schema_app_node(), schema_faq_node($faqs, '/vatglasses')],
];
require __DIR__ . '/partials/head.php';
?>
        <section class="hero page-hero-split">
            <div class="hero-inner">
                <div class="hero-copy">
                    <?= breadcrumbs_html($crumbs) ?>
                    <h1>VATGlasses sectors, live on your iPhone</h1>
                    <p class="hero-sub">VATGlasses is the community map of who controls which piece of VATSIM airspace. VatSight brings it to iPhone and iPad: see exactly which ATC sectors are online, merge them per controller, filter them by altitude, and tap any sector for the controller behind it.</p>
                    <div class="hero-actions">
                        <?= app_store_badge() ?>
                        <a class="btn-secondary" href="#how-it-works">How it works <?= icon('arrow') ?></a>
                    </div>
                    <ul class="hero-meta">
                        <li>Every VATGlasses region</li>
                        <li>Stored on your phone</li>
                        <li>Free</li>
                    </ul>
                </div>
                <div class="hero-visual">
                    <?= phone_shot('merged-sectors', ['eager' => true, 'caption' => '', 'class' => 'phone-hero']) ?>
                </div>
            </div>
        </section>

        <section class="split-section">
            <div class="section-inner split">
                <div class="split-copy prose">
                    <h2>What VATGlasses adds to a VATSIM map</h2>
                    <p>A controller’s callsign tells you roughly where they are. <code>EGTT_W_CTR</code> is somewhere in London’s airspace, but not which part, from what level, or what happens when the controller next to them logs off.</p>
                    <p><a href="https://vatglasses.uk" target="_blank" rel="noopener">VATGlasses</a> answers that. Volunteers from each vACC publish their airspace as open data: every sector’s shape, its lower and upper level, the ATC positions that can own it, and the order in which ownership passes down when positions are offline.</p>
                    <p>VatSight takes that dataset and runs it against live VATSIM data on your phone, so the map shows the airspace each controller is responsible for <em>right now</em>, not just a dot on their airport.</p>
                    <p>Want the background? Read <a href="/guides/what-is-vatglasses">What is VATGlasses?</a></p>
                </div>
                <div class="split-visual">
                    <?= phone_shot('blended-sectors') ?>
                </div>
            </div>
        </section>

        <section class="features" id="how-it-works">
            <div class="section-inner">
                <div class="section-head">
                    <h2>How VatSight matches controllers to sectors</h2>
                    <p>The same steps run every time the VATSIM data refreshes, every 15 seconds by default.</p>
                </div>
                <ol class="steps">
                    <li>
                        <h3>Download the dataset once</h3>
                        <p>On first launch VatSight downloads the whole <a class="link-text" href="https://github.com/lennycolton/vatglasses-data" target="_blank" rel="noopener">vatglasses-data</a> repository from GitHub as one zip and reads every region’s file on your phone. The result is saved, so sectors appear instantly from then on. Once a week VatSight checks for a newer version.</p>
                    </li>
                    <li>
                        <h3>Match each controller to a position</h3>
                        <p>Every VATGlasses position lists its callsign prefixes, its type and usually a frequency. A controller matches when their callsign starts with one of those prefixes and ends with the type, either <code>EDDF_TWR</code> or with a middle part like <code>EGTT_W_CTR</code>, and their frequency is the one VATGlasses expects. Checking the frequency stops two positions with the same prefix being mixed up.</p>
                    </li>
                    <li>
                        <h3>Walk down the ownership list</h3>
                        <p>Each sector has an ordered list of positions that can own it. VatSight gives the sector to the first one that is online. If the approach controller who normally owns a sector logs off, it passes to the next position, often the centre above, and is redrawn in that controller’s colour.</p>
                    </li>
                    <li>
                        <h3>Fill the gaps</h3>
                        <p>Training sessions (callsigns with <code>_X_</code> or <code>_T_</code> in the middle) only take a sector when no regular controller matches, and observers are ignored. If an approach controller is online at an airport VATGlasses doesn’t cover, VatSight draws a 15 nm circle around the airport so their coverage still shows.</p>
                    </li>
                </ol>
            </div>
        </section>

        <section class="split-section">
            <div class="section-inner split split-reverse">
                <div class="split-copy prose">
                    <h2>Tools for reading busy airspace</h2>
                    <ul>
                        <li><strong>Merge sectors.</strong> A single controller can own a dozen sectors. Merging joins them into one outline per controller, so a busy FIR becomes a handful of clear shapes.</li>
                        <li><strong>Altitude filter.</strong> Slide from the ground to FL600, in 100 ft steps, and only sectors whose band covers that level stay visible. Tap an aircraft and the slider follows its altitude, showing just the sectors that matter to that flight. Merging and the altitude filter can’t be on together, because a merged outline has no single band; VatSight switches one off when you turn the other on, and restores your merge setting after.</li>
                        <li><strong>Inactive sectors.</strong> Draw every sector outline, online or not, to see how a country’s airspace is split up before you log on.</li>
                        <li><strong>Sector details.</strong> Tap any sector for its controller’s name, rating, frequency, logon time and controller info, plus the sector’s altitude band and its full ownership list, with offline positions folded away. Swipe the controller to add them as a friend.</li>
                    </ul>
                </div>
                <div class="split-visual">
                    <?= phone_shot('atc-details') ?>
                </div>
            </div>
        </section>

        <section class="split-section split-section-plain">
            <div class="section-inner split">
                <div class="split-copy prose">
                    <h2>For vACC sector maintainers</h2>
                    <p>If you maintain VATGlasses data, VatSight doubles as a test bench. Open <strong>Settings → Sector Maintainers</strong> and turn on developer mode to get:</p>
                    <ul>
                        <li><strong>Your own fork, on live traffic.</strong> Point VatSight at a public fork of vatglasses-data and see your changes against real controllers before they’re merged.</li>
                        <li><strong>Unmatched controllers.</strong> Every online controller VatSight couldn’t place in a sector, with their callsign and frequency, so missing positions are easy to find.</li>
                        <li><strong>Parse errors.</strong> Any file in the dataset that failed to load, and why.</li>
                        <li><strong>A sector debug panel</strong> on the map for checking positions one by one.</li>
                    </ul>
                    <p>Questions about the data format belong with the VATGlasses team; questions about how VatSight draws it are <a href="/contact">welcome here</a>.</p>
                </div>
                <div class="split-visual">
                    <?= phone_shot('show-inactive-sectors') ?>
                </div>
            </div>
        </section>

        <section class="faq" id="faq">
            <div class="section-inner">
                <div class="section-head">
                    <h2>VATGlasses questions</h2>
                </div>
                <?= faq_list($faqs) ?>
            </div>
        </section>

        <section class="related">
            <div class="section-inner">
                <div class="section-head">
                    <h2>More from VatSight</h2>
                </div>
                <?= related_pages('/vatglasses') ?>
                <p class="credit-note">Airspace data © VATGlasses contributors, used under <a class="link-text" href="https://creativecommons.org/licenses/by-nc-sa/4.0/" target="_blank" rel="noopener">CC BY-NC-SA 4.0</a>. VatSight is not affiliated with or endorsed by VATGlasses or VATSIM.</p>
            </div>
        </section>

        <?= download_panel('See who’s controlling what', 'VATGlasses sectors and the whole VATSIM network, free on iPhone and iPad.') ?>
<?php require __DIR__ . '/partials/footer.php'; ?>
