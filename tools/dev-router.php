<?php
// Development only: PHP's built-in server ignores .htaccess, so this mirrors
// public/.htaccess closely enough to preview the site locally. Not deployed.
//
//   php -S localhost:8080 -t public tools/dev-router.php
//
// Drafts and future-dated guides are visible on localhost (marked "Preview").
// Pages are required at the bottom, in the global scope, as under Apache.

// Tells csp_header() (partials/config.php) it is on the dev server, so the
// policy lets Five Server's live-reload script run. Never set in production,
// because this file is never deployed.
define('DEV_SERVER', true);

$root  = realpath(__DIR__ . '/../public');
$uri   = $_SERVER['REQUEST_URI'];
$path  = rawurldecode(parse_url($uri, PHP_URL_PATH) ?? '/');
$query = parse_url($uri, PHP_URL_QUERY);
$file  = $root . $path;

$script = null;
$status = 0;
$location = null;

if (preg_match('#^/partials(/|$)#', $path) || preg_match('/\.md$/i', $path) || preg_match('#/\.#', $path)) {
    [$script, $status] = ['error.php', 403];
} elseif (preg_match('#^/ios_privacy_policy(?:\.html|\.php)?/?$#', $path)) {
    $location = '/privacy_policy';
} elseif ($path !== '/' && str_ends_with($path, '/') && !is_dir($file)) {
    $location = rtrim($path, '/');
} elseif (preg_match('#^/index(\.html|\.php)?$#', $path)) {
    $location = '/';
} elseif ($path === '/sitemap.php') {
    $location = '/sitemap.xml';
} elseif (preg_match('#^/guides-feed(\.php)?$#', $path)) {
    $location = '/guides/feed.xml';
} elseif ($path === '/sitemap.xml') {
    $script = 'sitemap.php';
} elseif ($path === '/guides/feed.xml') {
    $script = 'guides-feed.php';
} elseif (preg_match('#^/guides/tag/([a-z0-9-]+)$#', $path, $m)) {
    [$script, $_GET['tag']] = ['guides.php', $m[1]];
} elseif (preg_match('#^/guides/([a-z0-9-]+)$#', $path, $m)) {
    [$script, $_GET['slug']] = ['guides.php', $m[1]];
} elseif (preg_match('#^/(.+)\.(php|html)$#', $path, $m) && !str_starts_with($path, '/phplist/')) {
    $location = '/' . $m[1];
} elseif ($path === '/') {
    $script = 'index.php';
} elseif (is_file($file)) {
    return false; // static file, served by the built-in server
} elseif (is_file($file . '.php')) {
    $script = ltrim($path, '/') . '.php';
} else {
    [$script, $status] = ['error.php', 404];
}

if ($location !== null) {
    header('Location: ' . $location . ($query ? '?' . $query : ''), true, 301);
    return true;
}
if ($status) {
    http_response_code($status);
    $_SERVER['REDIRECT_STATUS'] = $status;
}
unset($uri, $path, $query, $file, $location, $m);
chdir($root);
require $root . '/' . $script;
return true;
