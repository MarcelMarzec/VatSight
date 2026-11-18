<?php
defined('SITE') or exit;
// Roadmap data, shared by the home page and /roadmap. Add a release at the
// end; mark it 'current' and move the previous one to 'done'.

function roadmap_releases(): array
{
    return [
        [
            'status'  => 'done',
            'date'    => 'May 2026',
            'version' => 'v0.1.0',
            'title'   => 'Core foundations',
            'summary' => 'The first version of VatSight: a live Mapbox map with pilot icons, aircraft details, and the app’s own branding.',
            'items'   => [
                'Live radar map built with Mapbox',
                'Pilot icons with live position, heading and details',
                'App branding and first iOS icon',
                'Track your own CID and tracked friends’ CIDs',
            ],
        ],
        [
            'status'  => 'done',
            'date'    => 'Aug 2026',
            'version' => 'v0.2.0',
            'title'   => 'Visualising ATC sectors',
            'summary' => 'VATGlasses airspace data, controller info, search, and a big pass on UI and airport data.',
            'items'   => [
                'VATGlasses ATC sector data',
                'Controller info',
                'Search',
                'Airport data and active controllers at airports',
                'Light and dark mode, more map styling and UI refinement',
            ],
        ],
        [
            'status'  => 'done',
            'date'    => 'Sep 2026',
            'version' => 'v0.3.0',
            'title'   => 'Improving tools and UX',
            'summary' => 'Search refinements, altitude filtering, a debug menu, and merged VATGlasses sectors.',
            'items'   => [],
        ],
        [
            'status'  => 'done',
            'date'    => 'Oct 2026',
            'version' => 'v0.4.0',
            'title'   => 'Closed beta and UI refinement',
            'summary' => 'Polished the UI, fixed bugs, and refined the details ready for VatSight’s first public test.',
            'items'   => [],
        ],
        [
            'status'  => 'done',
            'date'    => 'Oct 2026',
            'version' => 'v0.5.0',
            'title'   => 'Open beta',
            'summary' => 'A public TestFlight beta, alongside a big performance update and new settings.',
            'items'   => [
                'Public TestFlight beta',
                'Big performance update',
                'Friends list for tracking other VATSIM users',
                'In-app roadmap and contact form',
                'Haptics and accessibility settings',
            ],
        ],
        [
            'status'  => 'current',
            'date'    => 'Now',
            'version' => 'v1.0.0',
            'title'   => 'Public launch',
            'summary' => 'VatSight is out on the App Store: free to download, with every feature included for everyone.',
            'items'   => [
                'Free on the App Store for iPhone and iPad',
                'Optional ads to support development: off by default, and they never lock or unlock a feature',
                'Support VatSight page with a link to GitHub Sponsors',
            ],
        ],
        [
            'status'  => 'planned',
            'date'    => 'Planned',
            'version' => 'v1.1.0',
            'title'   => 'First major update',
            'summary' => 'Better flight following, Navigraph integration, METAR and ATIS on the map, and push notifications.',
            'items'   => [
                'Follow your flight, with the current sector and a prediction of the next one',
                'Navigraph integration, including navdata and charts',
                'Fully rendered routes, including waypoints, airways, SIDs and STARs',
                'More detailed airport charts displayed directly on the map',
                'A visual representation of the current weather',
                'Bug fixing',
            ],
        ],
    ];
}

// $only limits the timeline to some statuses, e.g. ['current', 'planned'].
function roadmap_timeline(bool $expanded = false, ?array $only = null): string
{
    $out = '<ol class="roadmap-timeline">';
    foreach (roadmap_releases() as $release) {
        if ($only !== null && !in_array($release['status'], $only, true)) {
            continue;
        }
        $class = 'roadmap-item' . ($release['status'] === 'done' ? ' is-done' : '') . ($release['status'] === 'current' ? ' is-current' : '');
        $out .= '<li class="' . $class . '"><span class="roadmap-marker"></span><div class="roadmap-content">'
            . '<span class="roadmap-date">' . e($release['date'] . ' · ' . $release['version']) . '</span>'
            . '<h4>' . e($release['title']) . '</h4>'
            . '<p>' . e($release['summary']) . '</p>';
        if ($release['items']) {
            $out .= '<details class="roadmap-details"' . ($expanded ? ' open' : '') . '><summary>What’s included' . icon('chevron') . '</summary><ul>';
            foreach ($release['items'] as $item) {
                $out .= '<li>' . e($item) . '</li>';
            }
            $out .= '</ul></details>';
        }
        $out .= '</div></li>';
    }
    return $out . '</ol>';
}
