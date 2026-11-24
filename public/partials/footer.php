<?php
defined('SITE') or exit;
// Closes <main> and the document opened by partials/head.php.
?>
    </main>

    <footer>
        <div class="footer-inner">
            <div class="footer-about">
                <a class="footer-brand" href="/">
                    <img src="/images/Vatsightlogo.png" alt="" width="22" height="22">
                    VatSight
                </a>
                <p>A free VATSIM map and tracker for iPhone and iPad, with live VATGlasses ATC sectors.</p>
                <?= app_store_badge() ?>
            </div>
<?php foreach ($footerGroups as $heading => $links): ?>
            <nav class="footer-col" aria-label="<?= e($heading) ?>">
                <h2><?= e($heading) ?></h2>
                <ul>
<?php foreach ($links as $link): ?>
                    <li><a href="<?= e($link['href']) ?>"<?= !empty($link['external']) ? ' target="_blank" rel="noopener"' : '' ?>><?= e($link['label']) ?></a></li>
<?php endforeach; ?>
                </ul>
            </nav>
<?php endforeach; ?>
        </div>
        <p class="footer-disclaimer">VatSight is an independent project and is not affiliated with or endorsed by VATSIM or VATGlasses. Flight data is sourced from the VATSIM network; airspace data from VATGlasses under CC BY-NC-SA 4.0.</p>
        <p class="footer-copy">Hosted with <a href="<?= e(HOST_URL) ?>" target="_blank" rel="sponsored noopener">FyFeWeb</a>. That is an affiliate link: if you sign up through it, I may earn a commission.</p>
        <p class="footer-copy">© <?= date('Y') ?> Marcel Marzec</p>
    </footer>

</body>

</html>
