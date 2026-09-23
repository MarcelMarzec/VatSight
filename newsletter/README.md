# VatSight newsletter: phpList setup

The website side is already done:

| File | What it does |
| --- | --- |
| `public/phplist/` | The phpList install itself, served at `https://vatsight.com/phplist/`. It handles sign-up, confirm, manage and unsubscribe. |
| `public/index.html` | Email form in the "Get notified" section. It posts straight to phpList's subscribe page. |
| `public/style/style.css` | Styles for that form (bottom of the file) |
| `public/ios_privacy_policy.html` | Privacy policy covering the website and newsletter |
| `public/robots.txt`, `public/sitemap.xml` | `/phplist/` blocked from crawlers |
| `newsletter/phplist/*` | Source copies of the header (including the VatSight theme CSS for phpList's pages), footer, email template and email footer saved in phpList's admin |

Newsletter links:

- Subscribe: `https://vatsight.com/phplist/?p=subscribe&id=1`
- Manage subscription: `https://vatsight.com/phplist/?p=preferences&id=1`
- Unsubscribe: `https://vatsight.com/phplist/?p=unsubscribe&id=1`

The home page form expects **list ID 2** and **subscribe page ID 1**. If either changes, update `list[2]` and `id=1` in `public/index.html`.

---

## Checklist

Last updated 23 Sep 2026.

**Done**

- [x] phpList installed at `vatsight.com/phplist`, with auto-upgrade and backups on
- [x] phpList admin: VatSight settings, page theme, emails, subscribe page, list and template
- [x] `news@`, `bounces@` and `contact@` mailboxes exist
- [x] SPF and DKIM in Cloudflare (DNS only), DMARC record added
- [x] Bounces password set in `config.php`; config uploaded (live pages show the text credit, so the new settings are active)
- [x] Website uploaded
- [x] Cron jobs added
- [x] Admin password changed
- [x] `news@` forwards to `contact@`
- [x] `public/phplist/` and `public/phplist*.zip` in `.gitignore`

**To do**

- [ ] Find your host's hourly email limit (support ticket or the host's knowledge base). If it's under 300, lower `MAILQUEUE_BATCH_SIZE` in the server's config.
- [ ] Fix the two cron commands: they contain `/home/marcelma` twice. Paste the exact lines from step 6.
- [x] Clean-up script uploaded to `/home/marcelma/`
- [ ] Add the clean-up cron job (step 6, third job).
- [ ] Check the cron jobs are running (step 6, "Checking the cron jobs work").
- [ ] Delete `phplist/config/config.php.orig` from the server. It's an old copy with the database password.
- [ ] Dismiss "Configure attributes" in the phpList checklist. No attributes are needed.
- [ ] Test end to end (step 7).
- [ ] Occasional housekeeping (step 8).

---

## 1. Email accounts and DNS (done)

1. Create **`news@vatsight.com`**. This is the From address. Point it at your normal inbox with a forwarder if you like.
2. Create **`bounces@vatsight.com`** as a real mailbox with a password. phpList reads bounces from it.
3. Go to **cPanel → Email Deliverability**, select `vatsight.com` and copy the **SPF** and **DKIM** records it suggests into **Cloudflare DNS**. cPanel can't install them itself because your DNS is at Cloudflare. Leave these records **DNS only** (grey cloud).
4. Add a DMARC record in Cloudflare: `TXT _dmarc` → `v=DMARC1; p=none; rua=mailto:contact@marcelmarzec.com`. You can tighten it to `p=quarantine` once everything passes.
5. Ask your host, or check their docs, how many emails per hour your account may send. You'll need that number in step 3.

## 2. phpList install (done)

phpList 3.7.0 lives in `public/phplist/` and is served at `https://vatsight.com/phplist/` (admin: `/phplist/admin/`). In Softaculous → All Installations, make sure **auto-upgrade** and **automated backups** are on.

> The whole `public/phplist/` folder (and any `public/phplist*.zip`) is in `.gitignore`, so the install and its passwords never go to GitHub. Upload phpList changes to the server with cPanel File Manager only.

## 3. `public/phplist/config/config.php` (done)

The repo copy has been updated. The original is saved as `config.php.orig`. Changes made:

- Tracking off: `CLICKTRACK 0`, `ALWAYS_ADD_USERTRACK 0` (the privacy policy says you don't track).
- No remote "powered by" images or stats pings: `REGISTER 0`, `PAGETEXTCREDITS 1`, `EMAILTEXTCREDITS 1`, `NOSTATSCOLLECTION 1`.
- `NOTIFY_SPAM 0`. This stops an email to you every time a bot hits the form.
- Sending limits: `MAILQUEUE_BATCH_SIZE 250` per hour with `MAILQUEUE_AUTOTHROTTLE 1`. Lower it if your host's hourly limit is below about 300.
- `USE_ADMIN_DETAILS_FOR_MESSAGES 0`, so campaigns use the VatSight From address.
- Bounces go to `bounces@vatsight.com` over POP3/SSL.

**Before uploading:** replace `CHANGE-ME` in `$bounce_mailbox_password` with the bounces mailbox password. Then upload the file to `phplist/config/config.php` in vatsight.com's document root with cPanel File Manager. The live site still runs the old settings, which is why its pages show the remote "powered by phpList" image.

## 4. phpList admin settings (done)

Set in the admin on 23 Sep 2026: website and domain `vatsight.com`, all public URLs at `https://vatsight.com/phplist/`, organisation name VatSight, From `VatSight <news@vatsight.com>`, reply-to `contact@marcelmarzec.com`, VatSight public-page header and footer, email footer, and the confirm, welcome, unsubscribe and "personal link" emails. The files in `newsletter/phplist/` are the source for these if you ever need to paste them again.

## 5. List, subscribe page and template (done)

- List 2 was renamed **VatSight updates**. List 1 (`test`) is for test sends.
- Subscribe page 1: VatSight intro and thank-you text, single email field (double entry off), HTML only, list 2 preselected, and its own copy of the header, footer and messages updated.
- Template **VatSight** added and set as the campaign default.

## 6. Cron jobs

phpList sends campaigns in batches. These two cron jobs run it automatically:

Every 5 minutes (sends queued campaigns):

```
*/5 * * * * /usr/local/bin/php /home/marcelma/public_html/vatsight.com/phplist/admin/index.php -c /home/marcelma/public_html/vatsight.com/phplist/config/config.php -pprocessqueue > /dev/null 2>&1
```

Every hour (processes bounces):

```
0 * * * * /usr/local/bin/php /home/marcelma/public_html/vatsight.com/phplist/admin/index.php -c /home/marcelma/public_html/vatsight.com/phplist/config/config.php -pprocessbounces > /dev/null 2>&1
```

Daily at 03:15 (deletes sign-ups that were never confirmed after 30 days, as the privacy policy promises):

```
15 3 * * * /usr/local/bin/php /home/marcelma/phplist-cleanup-unconfirmed.php >> /home/marcelma/phplist-cleanup.log 2>&1
```

For this one, upload `newsletter/cron/phplist-cleanup-unconfirmed.php` to `/home/marcelma/`. That's your home folder, **outside** `public_html`, so it can't be opened from the web. It reads the database login from phpList's own `config.php`, so it holds no passwords itself. To preview what it would delete without deleting anything, run it once with `--dry-run`, for example as a one-off cron job. The results are logged to `/home/marcelma/phplist-cleanup.log`, one line per run with email addresses masked.

The **Process queue** button in the admin still works alongside cron, so you can also send straight away while a campaign is going out.

### Checking the cron jobs work

The first two jobs send their output to `/dev/null`, so you can't see it. To check them, change the end of each line from `> /dev/null 2>&1` to a log file:

```
... -pprocessqueue >> /home/marcelma/phplist-queue.log 2>&1
... -pprocessbounces >> /home/marcelma/phplist-bounces.log 2>&1
```

Wait 5 minutes for the queue job, or until the next full hour for the bounces job. Then open the log files in File Manager (`/home/marcelma/`, the folder above `public_html`).

- **Working:** phpList's start-up lines followed by queue or bounce processing messages, for example that there's nothing to send.
- **Broken:** errors such as `Could not open input file` (wrong path) or `Access denied` (database login).

Once they're working, switch the two lines back to `> /dev/null 2>&1`. The queue job runs 288 times a day, so its log would keep growing.

The real proof is a test campaign: send one to the **test** list, don't press Process queue, and within 5 minutes it should show as sent.

For the clean-up job, set its time to a few minutes from now with `--dry-run` added after the script name, then check `/home/marcelma/phplist-cleanup.log`. Once you see a line there, set the time back to `15 3` and remove `--dry-run`.

## 7. Test before announcing it

1. Sign up on `https://vatsight.com/#newsletter` with a personal address. You should land on phpList's VatSight-styled "Check your inbox" page and get the confirmation email.
2. Click the confirmation link and check that the VatSight-styled page appears.
3. Send a campaign to the **test** list only. Check the From name, template, footer links, and that Gmail shows its own "Unsubscribe" button next to the sender.
4. Click **Unsubscribe** in that email and confirm you're removed. Also try the Unsubscribe and Manage subscription pages linked in the phpList page footer.
5. Paste a test email into [mail-tester.com](https://www.mail-tester.com) and aim for 9/10 or better. This confirms SPF, DKIM and DMARC.

## 8. Ongoing housekeeping (keeps the privacy policy true)

- **Unconfirmed sign-ups** are deleted automatically by the daily clean-up job (step 6). Check `phplist-cleanup.log` now and then to make sure it's running.
- **Deletion requests:** find the subscriber and delete them completely, including from the blacklist, when someone asks.
- **Access requests:** open the subscriber's record, which shows their details and history, and send it to them within one month.
- Keep click and open tracking **off**. If you ever turn them on, update the privacy policy and newsletter page first, because both say you don't track.
- Keep phpList updated through Softaculous.
- Check your hosting provider's terms include a data processing agreement (most do) and **where the server is located**. If it's outside the UK, the policy's international-transfer paragraph already covers it. Just make sure the host offers adequate safeguards.
