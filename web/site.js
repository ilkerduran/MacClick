(() => {
    const picker = document.querySelector("#language");
    const textNodes = document.querySelectorAll("[data-text]");
    const images = document.querySelectorAll("[data-alt]");
    const language = new URLSearchParams(window.location.search).get("lang");
    const supported = new Set(Array.from(picker.options, option => option.value));

    function applyLanguage(locale) {
        const strings = translations[locale] ?? {};
        document.documentElement.lang = { pt: "pt-PT", zh: "zh-Hans" }[locale] ?? locale;
        document.documentElement.dir = locale === "ar" ? "rtl" : "ltr";
        picker.value = locale;

        for (const node of textNodes) {
            node.textContent = strings[node.dataset.text] ?? englishText.get(node);
        }
        for (const image of images) {
            image.alt = strings[image.dataset.alt] ?? englishAlt.get(image);
        }
    }

    const englishText = new Map(Array.from(textNodes, node => [node, node.textContent]));
    const englishAlt = new Map(Array.from(images, image => [image, image.alt]));

    applyLanguage(supported.has(language) ? language : "en");
    picker.addEventListener("change", () => {
        applyLanguage(picker.value);
        if (location.protocol === "file:") return;
        const url = new URL(location.href);
        if (picker.value === "en") url.searchParams.delete("lang");
        else url.searchParams.set("lang", picker.value);
        history.replaceState(null, "", url);
    });
})();
