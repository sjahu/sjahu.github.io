# README

## About

This repo contains the source for my personal website, https://shumphries.ca/.

The site is built on [Jekyll](https://github.com/jekyll/jekyll) and hosted for free on [GitHub Pages](https://pages.github.com/) (thanks, GitHub!).

I built the site theme from scratch. It includes some custom liquid elements, which GitHub Pages does not support out of the box. For that reason, changes to the site are rendered to the [`public`](https://github.com/sjahu/sjahu.github.io/tree/public) branch by a GitHub Action and served statically from there, rather than being rendered automatically by Pages.

## Development

Notes to self:
- Enable the pre-commit hook to strip GPS location info from image EXIF metadata by running [`setup.sh`](https://github.com/sjahu/sjahu.github.io/blob/main/setup.sh)
- Serve locally by running [`util/serve`](https://github.com/sjahu/sjahu.github.io/blob/main/util/serve)
- Make sure to add any files added to the repo that shouldn't be published to the `exclude` list in [`_config.yml`](https://github.com/sjahu/sjahu.github.io/blob/main/_config.yml)
