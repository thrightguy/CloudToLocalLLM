# CloudToLocalLLM Design System

This design system provides a unified look and feel for the CloudToLocalLLM portal, desktop, and mobile apps. Use these guidelines and variables for all UI development.

## Color Palette
- **Primary:** `#a777e3` (purple)
- **Primary 2:** `#6e8efb` (blue)
- **Accent:** `#00c58e`
- **Background:** `#181a20` (main), `#23243a` (cards), `#f5f5f5` (alt)
- **Text:** `#f1f1f1` (main), `#b0b0b0` (muted), `#2c3e50` (dark)
- **Success:** `#4caf50`
- **Warning:** `#ffa726`
- **Danger:** `#ff5252`
- **Info:** `#2196f3`

## Typography
- **Font Family:** 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif
- **Headings:** Bold, large, white or accent color, with subtle shadow
- **Body:** 16px, 1.5 line height, clear contrast

## Spacing & Layout
- **Border Radius:** 16px (cards), 4px (buttons/inputs)
- **Box Shadow:** 0 4px 24px 0 #0006 (cards), 0 2px 12px #0003 (logo)
- **Container:** Max width 1200px, centered, responsive padding

## Gradients
- **Header:** `linear-gradient(135deg, #6e8efb 0%, #a777e3 100%)`
- **Buttons:** `linear-gradient(90deg, #6e8efb 0%, #a777e3 100%)`

## Reusable Components
- **Header:** Gradient background, logo, large title, subtitle
- **Card:** Rounded, shadow, accent border, for info/feature blocks
- **Button:** Gradient, rounded, bold, hover/active states
- **Container/Grid:** Responsive, centered, with padding
- **Typography:** Headings, body, muted text, lists

## Usage
- Import `design-system.scss` in your stylesheets.
- Use the provided CSS variables for all colors, spacing, and typography.
- Use the card, button, and header classes for consistent UI elements.

## Platform Guidance
- **Web:** Use the design system as-is for the portal.
- **Desktop:** Mirror the color palette, gradients, and card/button styles. Use sidebar navigation for app sections.
- **Mobile:** Stack cards vertically, use the same gradients and rounded cards, large touch targets.

---

**Do not display any under construction banners or login links/buttons until the product is ready for those features.** 