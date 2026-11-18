// Contact form, progressive enhancement (same behaviour as marcelmarzec.com).
// Without JavaScript the form posts to Formspree, which redirects back to
// /contact?sent=1 on success. Formspree's redirect only fires on success, so
// this submits in the background to show an error here when something fails.
(function () {
  var form = document.querySelector('.contact-form')
  var ok = document.querySelector('.alert-success')
  var bad = document.querySelector('.alert-error')
  var captchaError = document.getElementById('captcha-error')
  if (!form || !ok || !bad || !window.fetch) return

  // enterprise.js exposes grecaptcha.enterprise; the classic api.js does not.
  function recaptcha() {
    if (!window.grecaptcha) return null
    return window.grecaptcha.enterprise || window.grecaptcha
  }

  form.addEventListener('submit', function (event) {
    event.preventDefault()
    var api = recaptcha()

    // Only enforce the tick once the widget is actually there to tick.
    if (api && typeof api.getResponse === 'function' && api.getResponse() === '') {
      captchaError.hidden = false
      return
    }
    captchaError.hidden = true

    var button = form.querySelector('button[type="submit"]')
    button.disabled = true
    ok.hidden = true
    bad.hidden = true

    fetch(form.action, {
      method: 'POST',
      body: new FormData(form),
      headers: { Accept: 'application/json' },
    })
      .then(function (response) {
        if (!response.ok) throw new Error(response.status)
        form.reset()
        ok.hidden = false
      })
      .catch(function () {
        bad.hidden = false
      })
      .then(function () {
        button.disabled = false
        // The token is single use, so the box has to be ticked again.
        if (api && typeof api.reset === 'function') api.reset()
      })
  })
})()
