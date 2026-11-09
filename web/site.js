(() => {
    const picker = document.querySelector("#language");
    const textNodes = document.querySelectorAll("[data-text]");
    const images = document.querySelectorAll("[data-alt]");
    const requestedLanguage = new URLSearchParams(window.location.search).get("lang");
    const supported = new Set(Array.from(picker.options, option => option.value));

    function supportedLanguage(tag) {
        const language = tag?.toLowerCase().split("-")[0];
        return supported.has(language) ? language : undefined;
    }

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

    const browserLanguages = navigator.languages?.length ? navigator.languages : [navigator.language];
    const browserLanguage = browserLanguages.map(supportedLanguage).find(Boolean);
    applyLanguage(supportedLanguage(requestedLanguage) ?? browserLanguage ?? "en");
    picker.addEventListener("change", () => {
        applyLanguage(picker.value);
        if (location.protocol === "file:") return;
        const url = new URL(location.href);
        url.searchParams.set("lang", picker.value);
        history.replaceState(null, "", url);
    });
})();
