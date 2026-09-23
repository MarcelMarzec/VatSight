<?php
/**
 * VatSight: delete phpList sign-ups that were never confirmed.
 *
 * Someone who fills in the sign-up form but never clicks the confirmation
 * link stays in phpList as "unconfirmed". The privacy policy says these are
 * deleted within about a month, so this script removes any that are older
 * than MAX_AGE_DAYS. It does the same thing as phpList's
 * Subscribers → Reconcile subscribers → "delete unconfirmed subscribers".
 *
 * Only removes subscribers who:
 *   - are unconfirmed,
 *   - are not on the do-not-send (unsubscribe) list,
 *   - signed up more than MAX_AGE_DAYS ago, and
 *   - have never been sent a campaign (so bounced ex-subscribers are left alone).
 *
 * Run from cron (CLI only). Add --dry-run to see who would be deleted
 * without deleting anything.
 *
 *   /usr/local/bin/php /home/marcelma/phplist-cleanup-unconfirmed.php --dry-run
 */

// ---- Settings -------------------------------------------------------------
const PHPLIST_CONFIG = '/home/marcelma/public_html/vatsight.com/phplist/config/config.php';
const MAX_AGE_DAYS   = 30;
// ---------------------------------------------------------------------------

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$dryRun = in_array('--dry-run', $argv, true);
$stamp  = date('Y-m-d H:i:s');

if (!is_readable(PHPLIST_CONFIG)) {
    fwrite(STDERR, "[$stamp] Cannot read phpList config at " . PHPLIST_CONFIG . "\n");
    exit(1);
}

// phpList's config.php only sets variables and constants.
require PHPLIST_CONFIG;

$tablePrefix     = isset($table_prefix) ? $table_prefix : 'phplist_';
$userTablePrefix = isset($usertable_prefix) ? $usertable_prefix : 'phplist_user_';

// Same table layout phpList uses in admin/init.php and admin/inc/userlib.php
$t = [
    'user'                 => $userTablePrefix . 'user',
    'user_attribute'       => $userTablePrefix . 'user_attribute',
    'user_history'         => $userTablePrefix . 'user_history',
    'listuser'             => $tablePrefix . 'listuser',
    'usermessage'          => $tablePrefix . 'usermessage',
    'user_message_bounce'  => $tablePrefix . 'user_message_bounce',
    'user_message_forward' => $tablePrefix . 'user_message_forward',
    'user_message_view'    => $tablePrefix . 'user_message_view',
    'linktrack_uml_click'  => $tablePrefix . 'linktrack_uml_click',
];

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
try {
    $db = new mysqli(
        $database_host,
        $database_user,
        $database_password,
        $database_name,
        isset($database_port) && $database_port ? (int) $database_port : null,
        isset($database_socket) && $database_socket ? $database_socket : null
    );
    $db->set_charset('utf8mb4');
} catch (mysqli_exception $e) {
    fwrite(STDERR, "[$stamp] Database connection failed: " . $e->getMessage() . "\n");
    exit(1);
}

$sql = sprintf(
    'SELECT u.id, u.email, u.entered FROM `%s` u
      WHERE u.confirmed = 0
        AND u.blacklisted = 0
        AND u.entered < (NOW() - INTERVAL %d DAY)
        AND NOT EXISTS (SELECT 1 FROM `%s` um WHERE um.userid = u.id)',
    $t['user'], MAX_AGE_DAYS, $t['usermessage']
);
$rows = $db->query($sql)->fetch_all(MYSQLI_ASSOC);

if (!$rows) {
    echo "[$stamp] No unconfirmed sign-ups older than " . MAX_AGE_DAYS . " days.\n";
    exit(0);
}

// Tables whose subscriber column is called `user` rather than `userid`
$byUserColumn = ['user_message_bounce', 'user_message_forward'];
$deleted = 0;

foreach ($rows as $row) {
    $id = (int) $row['id'];
    // Don't write full addresses to the log
    $masked = preg_replace('/(?<=^.).*(?=@)/', '***', $row['email']);

    if ($dryRun) {
        echo "[$stamp] Would delete #$id $masked (signed up {$row['entered']})\n";
        continue;
    }

    $db->begin_transaction();
    try {
        foreach ($t as $key => $table) {
            if ($key === 'user') {
                continue;
            }
            $col = in_array($key, $byUserColumn, true) ? 'user' : 'userid';
            try {
                $db->query(sprintf('DELETE FROM `%s` WHERE `%s` = %d', $table, $col, $id));
            } catch (mysqli_sql_exception $e) {
                // 1146 = table doesn't exist in this phpList version; skip it
                if ($e->getCode() !== 1146) {
                    throw $e;
                }
            }
        }
        $db->query(sprintf('DELETE FROM `%s` WHERE id = %d', $t['user'], $id));
        $db->commit();
        $deleted++;
    } catch (Throwable $e) {
        $db->rollback();
        fwrite(STDERR, "[$stamp] Failed to delete #$id: " . $e->getMessage() . "\n");
    }
}

echo $dryRun
    ? "[$stamp] Dry run: " . count($rows) . " unconfirmed sign-up(s) would be deleted.\n"
    : "[$stamp] Deleted $deleted unconfirmed sign-up(s) older than " . MAX_AGE_DAYS . " days.\n";
