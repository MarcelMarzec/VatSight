<!DOCTYPE html>
<html lang="en">

<head>
    <title>VatSight — Live VATSIM Radar &amp; VatGlasses ATC Sectors for iOS</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="keywords" content="Vatsight, Vatsim, VATSIM radar, VATSIM tracker, VatGlasses, VatGlasses sectors, virtual ATC, flight simulator, iOS VATSIM app" />
    <meta name="description" content="VatSight is a free, open-source VATSIM radar for iOS. Live traffic, VatGlasses ATC sectors and airport activity on one clean map." />
    <meta name="author" content="Marcel Marzec" />
    <meta name="robots" content="index, follow" />
    <meta name="theme-color" content="#090909" />
    <meta property="og:description" content="A free, open-source VATSIM radar for iOS. Live traffic, VatGlasses ATC sectors and airport activity on one clean map." />
    <meta property="og:site_name" content="VatSight" />
    <meta property="og:title" content="VatSight — Live VATSIM Radar &amp; VatGlasses ATC Sectors for iOS" />
    <meta property="og:type" content="website" />
    <meta property="og:locale" content="en" />
    <meta property="og:url" content="https://vatsight.com" />
    <meta property="og:image" content="https://vatsight.com/images/Vatsightlogo.png" />
    <meta property="og:image:width" content="1024" />
    <meta property="og:image:height" content="1024" />
    <meta property="og:image:alt" content="VatSight app icon" />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="VatSight — Live VATSIM Radar &amp; VatGlasses ATC Sectors for iOS" />
    <meta name="twitter:description" content="A free, open-source VATSIM radar for iOS with live traffic and VatGlasses ATC sectors." />
    <meta name="twitter:image" content="https://vatsight.com/images/Vatsightlogo.png" />
    <meta name="twitter:image:alt" content="VatSight app icon" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" type="text/css" href="style/style.css?v=20260923"/>
    <link rel="canonical" href="https://vatsight.com" />
    <link rel="sitemap" type="application/xml" href="/sitemap.xml" />
    <link rel="icon" type="image/png" href="/images/favicon/favicon-96x96.png?v=20260509" sizes="96x96" />
    <link rel="icon" type="image/svg+xml" href="/images/favicon/favicon.svg?v=20260509" />
    <link rel="shortcut icon" href="/images/favicon/favicon.ico?v=20260509" />
    <link rel="apple-touch-icon" sizes="180x180" href="/images/favicon/apple-touch-icon.png?v=20260509" />
    <meta name="apple-mobile-web-app-title" content="VatSight.com" />
    <link rel="manifest" href="/images/favicon/site.webmanifest?v=20260509" />
    <script type="application/ld+json">
    {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": "VatSight",
        "url": "https://vatsight.com",
        "image": "https://vatsight.com/images/Vatsightlogo.png",
        "description": "VatSight is a free, open-source VATSIM radar for iOS. Live traffic, VatGlasses ATC sectors and airport activity on one clean map.",
        "applicationCategory": "UtilitiesApplication",
        "operatingSystem": "iOS",
        "author": {
            "@type": "Person",
            "name": "Marcel Marzec"
        },
        "offers": {
            "@type": "Offer",
            "price": "0",
            "priceCurrency": "USD"
        },
        "sameAs": [
            "https://github.com/MarcelMarzec/VatSight"
        ]
    }
    </script>
    <script type="application/ld+json">
    {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {
                "@type": "Question",
                "name": "What is VatSight?",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": "VatSight is a free, open-source VATSIM radar app for iOS. It shows live pilot and controller traffic, VatGlasses ATC sector boundaries, and airport activity on one clean map."
                }
            },
            {
                "@type": "Question",
                "name": "Is VatSight free to use?",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": "Yes. VatSight is completely free, with no account required. Rewarded ads are entirely optional and off by default."
                }
            },
            {
                "@type": "Question",
                "name": "What is VatGlasses and how does VatSight use it?",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": "VatGlasses is an open, community-maintained dataset of VATSIM ATC sector boundaries. VatSight renders these VatGlasses sectors live on its map, with support for merging overlapping sectors and filtering by altitude."
                }
            },
            {
                "@type": "Question",
                "name": "Do I need a VATSIM account to use VatSight?",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": "No. VatSight reads publicly available VATSIM network data, so you can view live traffic and ATC sectors without logging in or creating an account."
                }
            },
            {
                "@type": "Question",
                "name": "Is VatSight affiliated with VATSIM or VatGlasses?",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": "No. VatSight is an independent, open-source project. It is not affiliated with or endorsed by VATSIM or VatGlasses, though it relies on their public data."
                }
            },
            {
                "@type": "Question",
                "name": "When will VatSight be available on the App Store?",
                "acceptedAnswer": {
                    "@type": "Answer",
                    "text": "VatSight is currently in active development ahead of a public TestFlight beta, followed by a free App Store launch. Follow the project on GitHub for progress updates."
                }
            }
        ]
    }
    </script>
</head>

<body>

    <a class="skip-link" href="#main-content">Skip to main content</a>

    <?php include __DIR__ . '/partials/header.php'; ?>

    <main id="main-content">
        <section class="hero" id="top">
            <div class="hero-inner">
                <div class="hero-copy">
                    <a class="hero-kicker" href="#newsletter">
                        <span class="hero-kicker-dot"></span>
                        TestFlight beta opening soon &mdash; sign up to get an invite
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
                    </a>
                    <h1>See the virtual skies<br>come alive.</h1>
                    <p class="hero-sub">VatSight is a free, open-source radar for the VATSIM network — live traffic, VatGlasses ATC sectors, and airport activity, all on one clean map.</p>
                    <div class="hero-actions">
                        <span class="store-badge">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/></svg>
                            <span class="store-badge-text">
                                <small>Coming soon on the</small>
                                <strong>App Store</strong>
                            </span>
                        </span>
                        <a class="btn-secondary" href="https://github.com/MarcelMarzec/VatSight" target="_blank" rel="noopener">
                            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.58 2 12.25c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.48v-1.7c-2.78.62-3.37-1.36-3.37-1.36-.46-1.2-1.11-1.52-1.11-1.52-.91-.64.07-.63.07-.63 1 .07 1.53 1.05 1.53 1.05.9 1.57 2.36 1.11 2.93.85.09-.67.35-1.11.64-1.37-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.05a9.3 9.3 0 0 1 5 0c1.9-1.33 2.74-1.05 2.74-1.05.55 1.42.2 2.47.1 2.73.64.72 1.03 1.63 1.03 2.75 0 3.93-2.34 4.79-4.57 5.05.36.32.68.94.68 1.9v2.82c0 .27.18.58.69.48A10.26 10.26 0 0 0 22 12.25C22 6.58 17.52 2 12 2Z"/></svg>
                            View on GitHub
                        </a>
                    </div>
                    <div class="hero-meta">
                        <span>iOS</span><span class="sep">·</span>
                        <span>Free to use</span><span class="sep">·</span>
                        <span>No account required</span>
                    </div>
                </div>
                <div class="hero-visual">
                    <div class="phone-visual">
                        <div class="phone-screen">
                            <img src="images/screenshots/uk-overview.webp" alt="VatSight radar map showing live VATSIM traffic and ATC sector boundaries over the United Kingdom" loading="eager">
                        </div>
                        <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                    </div>
                </div>
            </div>
        </section>

        <section class="features" id="features">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Everything you need on frequency</h2>
                    <p>Built for controllers, pilots, and spotters who live on the network.</p>
                </div>
                <div class="feature-grid">
                    <article class="feature-card">
                        <div class="feature-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 12V4"/><path d="M4 12a8 8 0 1 0 16 0 8 8 0 1 0-16 0Z" opacity="0.45"/><circle cx="12" cy="12" r="1.3" fill="currentColor" stroke="none"/></svg>
                        </div>
                        <h3>Live Radar</h3>
                        <p>Every pilot and controller on the VATSIM network, updated in real time on a smooth, interactive map.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 3 21 8 12 13 3 8"/><polyline points="3 13 12 18 21 13"/><polyline points="3 17.5 12 22 21 17.5"/></svg>
                        </div>
                        <h3>VatGlasses ATC Sectors</h3>
                        <p>Live airspace boundaries powered by Vatglasses. Merge overlapping sectors and filter by altitude.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="3"/><path d="M7 9.5h5M7 13.5h9"/></svg>
                        </div>
                        <h3>Full Flight Details</h3>
                        <p>Tap any aircraft for altitude, speed, heading and transponder, plus the complete filed flight plan.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M20 20l-4.35-4.35"/></svg>
                        </div>
                        <h3>Powerful Search</h3>
                        <p>Jump straight to any callsign, airport or controller in seconds — no scrolling the map to find it.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 21s7-7.58 7-12a7 7 0 1 0-14 0c0 4.42 7 12 7 12Z"/><circle cx="12" cy="9" r="2.4"/></svg>
                        </div>
                        <h3>Airport Activity</h3>
                        <p>ATIS, active controllers and current traffic at a glance for every airport on the network.</p>
                    </article>
                    <article class="feature-card">
                        <div class="feature-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6l7-3Z"/><path d="M9 12l2 2 4-4"/></svg>
                        </div>
                        <h3>Privacy First</h3>
                        <p>No accounts, no forced tracking. Rewarded ads are entirely optional — off by default, and only shown if you choose to enable them.</p>
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
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/uk-overview.webp" alt="VatSight radar map showing live VATSIM traffic and ATC sector boundaries over the United Kingdom" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>Live Vatsim Traffic.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/show-inactive-sectors.webp" alt="VatSight map settings for merging sectors, showing inactive sectors and toggling all airports" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>Show all of the inactive sectors.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/zoom-details.webp" alt="VatSight radar map in light mode showing ATC sectors and live traffic" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>The more you zoom in, the more details you'll see.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/pilot-details.webp" alt="VatSight flight detail card for a flight near Frankfurt, showing altitude, speed and filed flight plan" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>See any pilot's flight details.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/track-overlay.webp" alt="VatSight flight detail card with a pilot's live track and flight plan overlaid on the map" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>Show only the sectors relevant to the flight.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/merged-sectors.webp" alt="VatSight map showing merged, overlapping ATC sector boundaries over the Netherlands and Belgium" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>Merge controller sectors into an outline.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/blended-sectors.webp" alt="VatSight map showing blended, merged ATC sectors with overlapping colour highlights" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>All active sectors, no altitude filtering or merging.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/atc-details.webp" alt="VatSight radar map in light mode showing ATC sectors and live traffic" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>Find out all there is to know about each ATC sector.</figcaption>
                    </figure>
                    <figure class="phone-card">
                        <div class="phone-visual">
                            <div class="phone-screen">
                                <img src="images/screenshots/light-mode.webp" alt="VatSight radar map in light mode showing ATC sectors and live traffic" loading="lazy">
                            </div>
                            <img class="phone-frame" src="images/outline.png" alt="" aria-hidden="true">
                        </div>
                        <figcaption>Light mode, if you prefer it.</figcaption>
                    </figure>
                </div>
            </div>
        </section>

        <section class="opensource" id="open-source">
            <div class="section-inner">
                <div class="opensource-card">
                    <div>
                        <h2>Built in the open</h2>
                        <p>VatSight is source-available on GitHub from day one. Read the code, file an issue, or send a pull request — the whole app is built with the community watching.</p>
                        <a class="btn-primary" href="https://github.com/MarcelMarzec/VatSight" target="_blank" rel="noopener">
                            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.58 2 12.25c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.48v-1.7c-2.78.62-3.37-1.36-3.37-1.36-.46-1.2-1.11-1.52-1.11-1.52-.91-.64.07-.63.07-.63 1 .07 1.53 1.05 1.53 1.05.9 1.57 2.36 1.11 2.93.85.09-.67.35-1.11.64-1.37-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.05a9.3 9.3 0 0 1 5 0c1.9-1.33 2.74-1.05 2.74-1.05.55 1.42.2 2.47.1 2.73.64.72 1.03 1.63 1.03 2.75 0 3.93-2.34 4.79-4.57 5.05.36.32.68.94.68 1.9v2.82c0 .27.18.58.69.48A10.26 10.26 0 0 0 22 12.25C22 6.58 17.52 2 12 2Z"/></svg>
                            Star on GitHub
                        </a>
                    </div>
                    <ul class="opensource-list">
                        <li>
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l4 4 10-10"/></svg>
                            View and scrutinise the entire codebase
                        </li>
                        <li>
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l4 4 10-10"/></svg>
                            Contribute fixes, features and improvements
                        </li>
                        <li>
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12l4 4 10-10"/></svg>
                            Free to use — not for resale as a competing app
                        </li>
                    </ul>
                </div>

                <div class="roadmap">
                    <div class="roadmap-head">
                        <div>
                            <h3>Roadmap</h3>
                            <p>Where VatSight has been, and where it's headed.</p>
                        </div>
                        <span class="roadmap-scroll-hint" aria-hidden="true">
                            Scroll for more
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg>
                        </span>
                    </div>
                    <ol class="roadmap-timeline">
                        <li class="roadmap-item is-done">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">May 2026 · v0.1.0</span>
                                <h4>Core foundations</h4>
                                <p>The first version of VatSight: a live Mapbox map with pilot icons, aircraft details, and the app's own branding.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>Live radar map built with Mapbox</li>
                                        <li>Pilot icons with live position, heading and details</li>
                                        <li>App branding and first iOS icon</li>
                                        <li>Track your own CID and tracked friends' CIDs</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                        <li class="roadmap-item is-done">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">Aug 2026 · v0.2.0</span>
                                <h4>Going deeper</h4>
                                <p>VatGlasses airspace data, controller info, search, and a big pass on UI and airport data.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>VatGlasses ATC sector data</li>
                                        <li>Controller info</li>
                                        <li>Search</li>
                                        <li>Airport data and active controllers at airports</li>
                                        <li>Light and dark mode, more map styling and UI refinement</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                        <li class="roadmap-item is-done">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">Sep 2026 · v0.3.0</span>
                                <h4>Sharper tools</h4>
                                <p>Search refinements, altitude filtering, a debug menu, and merged VatGlasses sectors.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>Search refinements</li>
                                        <li>Altitude filtering</li>
                                        <li>Debug menus</li>
                                        <li>Merged VatGlasses sectors</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                        <li class="roadmap-item is-current">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">Now · v0.4.0</span>
                                <h4>Final touches</h4>
                                <p>Polishing the UI, fixing bugs, and refining the details as VatSight nears its first public test.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>Synthetic sectors and smaller sector fixes</li>
                                        <li>Bug fixes and UI polish</li>
                                        <li>Codebase refactor ahead of testing</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                        <li class="roadmap-item">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">Coming soon · v0.5.0</span>
                                <h4>Open beta testing</h4>
                                <p>A public TestFlight beta opens so early users can try VatSight and help shape it before launch.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>Public TestFlight beta invites</li>
                                        <li>Bug reports and feedback shape the final release</li>
                                        <li>Wider device and iOS version testing</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                        <li class="roadmap-item">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">Planned · v1.0.0</span>
                                <h4>Public launch</h4>
                                <p>VatSight releases on the App Store — free to download, with every current feature included.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>Free download on the App Store</li>
                                        <li>Every current feature included, no paywall</li>
                                        <li>Continued updates based on community feedback</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                        <li class="roadmap-item">
                            <span class="roadmap-marker"></span>
                            <div class="roadmap-content">
                                <span class="roadmap-date">Planned · v1.1.0</span>
                                <h4>First update</h4>
                                <p>Navigraph integration — routes, airways, SIDs and STARs on the map, more detailed airport charts, and bug fixes.</p>
                                <details class="roadmap-details">
                                    <summary>What's included<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg></summary>
                                    <ul>
                                        <li>Navigraph integration</li>
                                        <li>Visualise fixes, airways, SIDs and STARs on the map</li>
                                        <li>More detailed airport charts</li>
                                        <li>Bug fixing</li>
                                    </ul>
                                </details>
                            </div>
                        </li>
                    </ol>
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
                        <div class="credits-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 12V4"/><path d="M4 12a8 8 0 1 0 16 0 8 8 0 1 0-16 0Z" opacity="0.45"/><circle cx="12" cy="12" r="1.3" fill="currentColor" stroke="none"/></svg>
                        </div>
                        <div>
                            <h3>VATSIM Data API</h3>
                            <p>Live pilot and controller positions, flight plans, and ATIS text are pulled directly from the public <a class="link-text" href="https://data.vatsim.net" target="_blank" rel="noopener">VATSIM Data API</a>. VatSight is not affiliated with or endorsed by VATSIM.</p>
                        </div>
                    </div>
                    <div class="credits-card">
                        <div class="credits-icon">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 3 21 8 12 13 3 8"/><polyline points="3 13 12 18 21 13"/><polyline points="3 17.5 12 22 21 17.5"/></svg>
                        </div>
                        <div>
                            <h3>VatGlasses</h3>
                            <p>ATC sector boundaries are sourced from <a class="link-text" href="https://vatglasses.uk" target="_blank" rel="noopener">VatGlasses</a>, an open, community-maintained airspace dataset kept accurate by vACC staff across the VATSIM network, via their <a class="link-text" href="https://github.com/lennycolton/vatglasses-data" target="_blank" rel="noopener">public data repository</a>. VatSight is not affiliated with or endorsed by VatGlasses.</p>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <section class="faq" id="faq">
            <div class="section-inner">
                <div class="section-head">
                    <h2>Frequently asked questions</h2>
                    <p>Everything you might want to know about VatSight, VATSIM and VatGlasses on iOS.</p>
                </div>
                <div class="faq-list">
                    <details class="faq-item">
                        <summary>What is VatSight?
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
                        </summary>
                        <p>VatSight is a free, open-source VATSIM radar app for iOS. It shows live pilot and controller traffic, VatGlasses ATC sector boundaries, and airport activity on one clean map.</p>
                    </details>
                    <details class="faq-item">
                        <summary>Is VatSight free to use?
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
                        </summary>
                        <p>Yes. VatSight is completely free, with no account required. Rewarded ads are entirely optional and off by default.</p>
                    </details>
                    <details class="faq-item">
                        <summary>What is VatGlasses and how does VatSight use it?
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
                        </summary>
                        <p>VatGlasses is an open, community-maintained dataset of VATSIM ATC sector boundaries. VatSight renders these VatGlasses sectors live on its map, with support for merging overlapping sectors and filtering by altitude.</p>
                    </details>
                    <details class="faq-item">
                        <summary>Do I need a VATSIM account to use VatSight?
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
                        </summary>
                        <p>No. VatSight reads publicly available VATSIM network data, so you can view live traffic and ATC sectors without logging in or creating an account.</p>
                    </details>
                    <details class="faq-item">
                        <summary>Is VatSight affiliated with VATSIM or VatGlasses?
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
                        </summary>
                        <p>No. VatSight is an independent, open-source project. It is not affiliated with or endorsed by VATSIM or VatGlasses, though it relies on their public data.</p>
                    </details>
                    <details class="faq-item">
                        <summary>When will VatSight be available on the App Store?
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>
                        </summary>
                        <p>VatSight is currently in active development ahead of a public TestFlight beta, followed by a free App Store launch. Follow the project on GitHub for progress updates.</p>
                    </details>
                </div>
            </div>
        </section>

        <section class="final-cta" id="newsletter">
            <div class="section-inner">
                <span class="cta-eyebrow">Newsletter &middot; beta sign-ups open</span>
                <h2>Be the first to know when TestFlight testing opens</h2>
                <p>VatSight is heading into closed testing on TestFlight before its free App Store launch. Sign up and we'll email you the moment a beta invite is ready, plus the App Store launch and any major updates. A few emails a year, never spam.</p>
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
                        <button type="submit" name="subscribe" value="Subscribe">Notify me</button>
                    </div>
                    <p class="signup-legal">We'll email you a link to confirm. Unsubscribe any time with one click. See our <a href="/privacy_policy#newsletter">Privacy Policy</a>.</p>
                </form>
                <div class="hero-actions">
                    <a class="btn-secondary" href="https://github.com/MarcelMarzec/VatSight" target="_blank" rel="noopener">
                        <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.58 2 12.25c0 4.53 2.87 8.37 6.84 9.73.5.09.68-.22.68-.48v-1.7c-2.78.62-3.37-1.36-3.37-1.36-.46-1.2-1.11-1.52-1.11-1.52-.91-.64.07-.63.07-.63 1 .07 1.53 1.05 1.53 1.05.9 1.57 2.36 1.11 2.93.85.09-.67.35-1.11.64-1.37-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.31.1-2.73 0 0 .84-.28 2.75 1.05a9.3 9.3 0 0 1 5 0c1.9-1.33 2.74-1.05 2.74-1.05.55 1.42.2 2.47.1 2.73.64.72 1.03 1.63 1.03 2.75 0 3.93-2.34 4.79-4.57 5.05.36.32.68.94.68 1.9v2.82c0 .27.18.58.69.48A10.26 10.26 0 0 0 22 12.25C22 6.58 17.52 2 12 2Z"/></svg>
                        Follow on GitHub
                    </a>
                    <a class="btn-secondary" href="https://marcelmarzec.com/contact-me" target="_blank" rel="noopener">Get in Contact</a>
                </div>
            </div>
        </section>
    </main>

    <?php include __DIR__ . '/partials/footer.php'; ?>

</body>

</html>
