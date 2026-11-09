# MacClick website

Open `index.html` locally, or serve this directory with a static HTTP server. The site uses English by default. The language picker also supports Turkish, Spanish, European Portuguese, Arabic, Simplified Chinese, and Russian. To share a translated page, use a URL such as `?lang=tr`. Arabic uses right-to-left layout.

The site has no build step. Its assets and scripts use relative paths, so the same files work at a GitHub Pages project path or on a custom domain. The photographs in `images/` are generated illustrations. The app icon comes from the MacClick asset catalog.

## GitHub Pages

From the repository root, publish the committed contents of `web/` to a dedicated Pages branch.

```sh
git subtree push --prefix=web origin gh-pages
```

In GitHub, open **Settings → Pages**, select **Deploy from a branch**, then choose **gh-pages** and **/(root)**. Repeat the command after committing website updates. [GitHub Pages publishing sources](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

## Custom domain

For GitHub Pages, verify your domain and set it under **Settings → Pages → Custom domain**. Follow GitHub’s DNS instructions for your domain type. With another static host, upload the contents of `web/` as the site root and configure DNS through that host. [GitHub Pages custom domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/about-custom-domains-and-github-pages)
