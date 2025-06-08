# Unified Flutter Web Architecture

## Overview

CloudToLocalLLM v3.4.0+ implements a unified Flutter-based web architecture that consolidates both marketing content and application functionality into a single codebase. This eliminates the need for separate static site containers while maintaining clear separation between marketing and application routes.

## Architecture Changes

### Before (Multi-Container)
```
cloudtolocalllm.online → static-site container (HTML/CSS)
app.cloudtolocalllm.online → flutter-app container (Flutter web)
docs.cloudtolocalllm.online → static-site container (VitePress docs)
```

### After (Unified Flutter)
```
cloudtolocalllm.online → flutter-app container (Flutter marketing pages)
app.cloudtolocalllm.online → flutter-app container (Flutter chat interface)
docs.cloudtolocalllm.online → static-site container (VitePress docs - unchanged)
```

## Domain Routing Strategy

### Main Domain (cloudtolocalllm.online)
- **Purpose**: Marketing homepage and download information
- **Routes**: `/` (homepage), `/download` (installation guide)
- **Platform**: Web-only (`kIsWeb` detection)
- **Authentication**: Not required for marketing content

### App Subdomain (app.cloudtolocalllm.online)
- **Purpose**: Main application interface
- **Routes**: `/chat`, `/settings`, `/login`, `/callback`
- **Platform**: Web and desktop
- **Authentication**: Required for application features
- **Redirect**: Root `/` redirects to `/chat`

### Docs Subdomain (docs.cloudtolocalllm.online)
- **Purpose**: Technical documentation
- **Technology**: VitePress (unchanged)
- **Container**: static-site (docs path only)

## Flutter Route Configuration

### Platform-Specific Routing
```dart
// Home route - platform-specific behavior
GoRoute(
  path: '/',
  name: 'home',
  builder: (context, state) {
    if (kIsWeb) {
      return const HomepageScreen(); // Marketing homepage
    } else {
      return const HomeScreen(); // Desktop chat interface
    }
  },
),

// Download route - web-only
GoRoute(
  path: '/download',
  name: 'download',
  builder: (context, state) {
    if (kIsWeb) {
      return const DownloadScreen();
    } else {
      return const HomeScreen(); // Fallback for desktop
    }
  },
),
```

### Authentication Logic
```dart
redirect: (context, state) {
  final isHomepage = state.matchedLocation == '/' && kIsWeb;
  final isDownload = state.matchedLocation == '/download' && kIsWeb;
  
  // Allow marketing pages without authentication
  if (kIsWeb && (isHomepage || isDownload)) {
    return null;
  }
  
  // Require authentication for app routes
  if (!isAuthenticated) {
    return '/login';
  }
  
  return null;
},
```

## Implementation Details

### Marketing Screens
- **Location**: `lib/screens/marketing/`
- **Files**: `homepage_screen.dart`, `download_screen.dart`
- **Design**: Material Design 3 with static site color scheme
- **Responsive**: Mobile-first responsive design
- **Content**: Replicates existing static site functionality

### Nginx Configuration
```nginx
# Main domain - Flutter marketing
server {
    server_name cloudtolocalllm.online;
    location / {
        proxy_pass http://flutter-app;
        # Flutter-specific headers
    }
}

# App subdomain - Flutter application
server {
    server_name app.cloudtolocalllm.online;
    location = / {
        return 302 /chat; # Redirect to chat interface
    }
    location / {
        proxy_pass http://flutter-app;
    }
}
```

## Benefits

### Unified Codebase
- Single Flutter application handles all web functionality
- Consistent theming and component library
- Shared authentication and state management
- Simplified deployment and maintenance

### Performance
- Single container for web functionality
- Shared Flutter assets and dependencies
- Reduced infrastructure complexity
- Faster build and deployment times

### Developer Experience
- Single codebase for all web features
- Consistent development environment
- Shared tooling and testing infrastructure
- Simplified debugging and monitoring

## Migration Path

### Phase 1: Implementation ✅
- [x] Create Flutter marketing screens
- [x] Update router with platform detection
- [x] Configure nginx domain routing
- [x] Update Docker configuration

### Phase 2: Testing
- [ ] Verify homepage functionality on main domain
- [ ] Test download page responsiveness
- [ ] Validate app subdomain chat access
- [ ] Confirm authentication flows

### Phase 3: Deployment
- [ ] Deploy updated nginx configuration
- [ ] Update DNS routing if needed
- [ ] Monitor traffic and performance
- [ ] Validate all domain endpoints

### Phase 4: Cleanup
- [ ] Remove static homepage files
- [ ] Deprecate static-site container (docs only)
- [ ] Update deployment scripts
- [ ] Archive legacy static content

## Verification Checklist

### Domain Access
- [ ] `cloudtolocalllm.online` → Flutter homepage
- [ ] `cloudtolocalllm.online/download` → Flutter download page
- [ ] `app.cloudtolocalllm.online` → Redirects to `/chat`
- [ ] `app.cloudtolocalllm.online/chat` → Flutter chat interface
- [ ] `docs.cloudtolocalllm.online` → VitePress documentation

### Platform Behavior
- [ ] Web: Marketing routes accessible without auth
- [ ] Web: App routes require authentication
- [ ] Desktop: Marketing routes excluded from build
- [ ] Desktop: Direct access to chat interface

### Responsive Design
- [ ] Homepage mobile responsiveness
- [ ] Download page code block formatting
- [ ] Navigation consistency
- [ ] Button and link functionality

## Future Considerations

### Static Site Container
The static-site container will be retained for documentation hosting but can be further optimized:
- Remove homepage-related configurations
- Focus solely on docs.cloudtolocalllm.online
- Consider migrating docs to Flutter in future versions

### Performance Optimization
- Implement route-based code splitting
- Optimize Flutter web bundle size
- Add progressive web app features
- Consider service worker caching

### SEO and Analytics
- Add meta tags for marketing pages
- Implement structured data
- Configure analytics tracking
- Optimize for search engines
