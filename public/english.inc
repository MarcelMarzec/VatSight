<?php
/*
 * VatSight wording for phpList's public pages.
 *
 * phpList loads this file from the website's document root after its own
 * texts/english.inc, so anything set here replaces the default wording.
 * Living outside the phplist/ folder means it survives phpList upgrades.
 * Direct web access to .inc files is blocked in .htaccess.
 */

// Update your preferences: request a private link by email
$strPersonalLocationInfo = '
  <p>Enter the email address you subscribed with and we\'ll email you a private link to your subscription.</p>
  <p>From that link you can change your email address or email format, or unsubscribe.</p>
';
$strPersonalLocationSent = '<div class="information"><strong>Check your inbox.</strong> We\'ve emailed you a private link to manage your subscription. It can take a minute or two to arrive, so check your spam folder if you don\'t see it.</div>';
$strUserNotFound = '<p class="error">We couldn\'t find a subscription for that email address. Check it for typos, or <a href="https://vatsight.com/phplist/?p=subscribe&amp;id=1">subscribe here</a>.</p>';
