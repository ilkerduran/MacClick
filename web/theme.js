(() => {
    const root = document.documentElement;
    const systemTheme = window.matchMedia("(prefers-color-scheme: dark)");
    const themeColor = document.querySelector('meta[name="theme-color"]');
    const storageKey = "macclick-theme";

    try {
        const saved = window.localStorage.getItem(storageKey);
        if (saved === "dark" || saved === "light") root.dataset.theme = saved;
    } catch {
        // The system preference still works when storage is unavailable.
    }

    function isDark() {
        return (root.dataset.theme ?? (systemTheme.matches ? "dark" : "light")) === "dark";
    }

    function updateThemeColor() {
        themeColor.content = isDark() ? "#181320" : "#f8f7fc";
    }

    updateThemeColor();
    document.addEventListener("DOMContentLoaded", () => {
        const toggle = document.querySelector("#theme-toggle");

        function updateToggle() {
            toggle.setAttribute("aria-pressed", String(isDark()));
            updateThemeColor();
        }

        updateToggle();
        toggle.hidden = false;
        systemTheme.addEventListener("change", updateToggle);
        toggle.addEventListener("click", () => {
            root.dataset.theme = isDark() ? "light" : "dark";
            updateToggle();
            try {
                window.localStorage.setItem(storageKey, root.dataset.theme);
            } catch {
                // The selected theme remains active for this page.
            }
        });
    });
})();
