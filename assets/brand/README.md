# Shakapacker Brand Assets

This directory contains the canonical Shakapacker folded-S icon and lockup assets.

The root `apple-touch-icon.png`, `favicon.png`, and `favicon.svg` files are copies of these assets for repository tools, including Conductor's repo icon discovery. `assets/icon.png` is a generic high-resolution fallback for tools that look in `assets/`.

When updating the icon set, keep the discovery copies in sync in the same change:

- `favicon.svg` from `assets/brand/icon-tile.svg`
- `favicon.png` from `assets/brand/icon-32.png`
- `apple-touch-icon.png` from `assets/brand/icon-256.png`
- `assets/icon.png` from `assets/brand/icon-1024.png`

`lockup-light.png` is the raster preview and fallback. The dark lockup is SVG-only unless a consumer specifically needs a raster dark variant.
