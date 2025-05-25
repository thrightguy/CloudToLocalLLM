# CloudToLocalLLM Design System

This design system provides a unified look and feel for the CloudToLocalLLM portal, desktop, and mobile apps. Use these guidelines and variables for all UI development.

## 🎨 Color Palette
- **Primary:** `#a777e3` (purple) - Main brand color for buttons, links, and accents
- **Secondary:** `#6e8efb` (blue) - Supporting brand color for gradients and highlights
- **Accent:** `#00c58e` (green) - Success states and call-to-action elements
- **Background:** `#181a20` (main), `#23243a` (cards), `#f5f5f5` (light mode alt)
- **Text:** `#f1f1f1` (main), `#b0b0b0` (muted), `#2c3e50` (dark mode)
- **Success:** `#4caf50` - Positive feedback and success states
- **Warning:** `#ffa726` - Caution and warning states
- **Danger:** `#ff5252` - Error states and destructive actions
- **Info:** `#2196f3` - Informational content and neutral actions

## 📝 Typography
- **Font Family:** 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif
- **Headings:** Bold, large, white or accent color, with subtle shadow
- **Body:** 16px base size, 1.5 line height for optimal readability
- **Font Weights:** 400 (normal), 500 (medium), 600 (semi-bold), 700 (bold)

## 📐 Spacing & Layout
- **Border Radius:** 16px (cards), 4px (buttons/inputs)
- **Box Shadow:**
  - Cards: `0 4px 24px 0 rgba(0, 0, 0, 0.4)`
  - Small elements: `0 2px 12px rgba(0, 0, 0, 0.2)`
- **Container:** Max width 1200px, centered, responsive padding
- **Spacing Scale:** 4px, 8px, 12px, 16px, 24px, 32px, 48px

## 🌈 Gradients
- **Header:** `linear-gradient(135deg, #6e8efb 0%, #a777e3 100%)`
- **Buttons:** `linear-gradient(90deg, #6e8efb 0%, #a777e3 100%)`

## 🧩 Reusable Components

### Flutter Components
- **GradientAppBar:** App bar with gradient background and logo
- **GradientButton:** Primary action button with gradient background
- **SecondaryButton:** Secondary action button with outline style
- **ThemedCard:** Standard card component with consistent styling
- **InfoCard:** Card with icon, title, description, and actions
- **FeatureCard:** Highlight card for showcasing features
- **CircularLlmLogo:** Branded logo component

### CSS Components
- **Header:** Gradient background, logo, large title, subtitle
- **Card:** Rounded, shadow, accent border, for info/feature blocks
- **Button:** Gradient, rounded, bold, hover/active states
- **Container/Grid:** Responsive, centered, with padding

## 💻 Platform Implementation

### Flutter Applications (Web & Desktop)
```dart
// Import the unified theme
import 'package:cloudtolocalllm/config/theme.dart';

// Apply the theme
MaterialApp(
  theme: CloudToLocalLLMTheme.lightTheme,
  darkTheme: CloudToLocalLLMTheme.darkTheme,
  // ...
)

// Use standardized components
GradientButton(
  text: 'Action',
  onPressed: () {},
)

InfoCard(
  title: 'Title',
  description: 'Description',
  icon: Icons.info,
)
```

### Web/CSS Implementation
```css
/* Import design system variables */
:root {
  --color-primary: #a777e3;
  --color-secondary: #6e8efb;
  --gradient-header: linear-gradient(135deg, #6e8efb 0%, #a777e3 100%);
  /* ... other variables */
}

/* Use standardized classes */
.button {
  background: var(--gradient-button);
  border-radius: var(--border-radius-sm);
}

.card {
  background: var(--bg-card);
  border-radius: var(--border-radius);
  box-shadow: var(--box-shadow);
}
```

## 📱 Responsive Design
- **Mobile:** Stack cards vertically, larger touch targets (48px minimum)
- **Tablet:** Two-column layouts where appropriate
- **Desktop:** Multi-column layouts, sidebar navigation
- **Breakpoints:** 600px (mobile), 900px (tablet), 1200px (desktop)

## ✅ Implementation Status

### ✅ Completed
- [x] Unified Flutter theme system (`lib/config/theme.dart`)
- [x] Standardized color palette across all platforms
- [x] Gradient components (buttons, app bars)
- [x] Card components with consistent styling
- [x] Typography standardization
- [x] Web manifest theme colors updated
- [x] CSS variables aligned with Flutter theme

### 🔄 In Progress
- [ ] Login screen theme updates
- [ ] Chat screen theme updates
- [ ] Form component standardization

### 📋 Future Enhancements
- [ ] Dark/light mode toggle
- [ ] Accessibility improvements (WCAG compliance)
- [ ] Animation and transition standards
- [ ] Icon library standardization

## 🎯 Usage Guidelines

1. **Always use the design system colors** - Never hardcode color values
2. **Import theme files** - Use `CloudToLocalLLMTheme` in Flutter, CSS variables in web
3. **Consistent spacing** - Use the defined spacing scale
4. **Component reuse** - Prefer existing components over custom implementations
5. **Responsive design** - Test across all target screen sizes

## 🚀 Getting Started

### For Flutter Development
1. Import the theme: `import 'package:cloudtolocalllm/config/theme.dart';`
2. Apply to MaterialApp: `theme: CloudToLocalLLMTheme.lightTheme`
3. Use standardized components from `lib/components/`

### For Web Development
1. Include the CSS variables from `web/styles.css`
2. Use the predefined CSS classes
3. Follow the component patterns from `static_homepage/css/theme.css`

---

**This design system ensures visual consistency across all CloudToLocalLLM applications, providing users with a seamless experience regardless of platform.**