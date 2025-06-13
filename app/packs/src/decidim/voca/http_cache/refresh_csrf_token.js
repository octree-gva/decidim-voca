/**
 * On page load, refresh the CSRF token as it might comes from the cache.
 */
document.addEventListener("DOMContentLoaded", function() {
  const refreshRequest = fetch("/_/csrf/refresh", {
    method: "GET",
    headers: {
      "X-Requested-With": "XMLHttpRequest"
    }
  })
  refreshRequest.then(response => {
    if (response.ok) {
      const csrfToken = response.headers.get("X-CSRF-Token")
      document.querySelector("meta[name='csrf-token']").content = csrfToken
      window.Rails.refreshCSRFTokens();
    }
  })
})