/**
 * EZ Lineup Configuration
 * 
 * Change these settings to switch between backends:
 * - 'localStorage' : Data stored locally in browser (default, works offline)
 * - 'api'          : Data stored in Cloudflare D1 (requires internet, syncs across devices)
 */

// Function to detect if we're in production
function detectProduction() {
    if (typeof window === 'undefined') return false;
    const hostname = window.location.hostname;
    return hostname.includes('pages.dev') || 
           hostname.includes('ezlineup') ||
           (hostname !== 'localhost' && hostname !== '127.0.0.1' && !hostname.startsWith('192.168.'));
}

// Function to get API base URL
function getApiBaseUrl() {
    return detectProduction() 
        ? 'https://ezlineup-api.jgraham-evans.workers.dev'
        : 'http://localhost:8787';
}

const CONFIG = {
    // Storage backend: 'localStorage' or 'api'
    backend: 'api',
    
    // API base URL (only used when backend is 'api')
    // - Automatically uses production URL when deployed
    // - Uses localhost for local development
    get apiBaseUrl() {
        return getApiBaseUrl();
    },
    
    // Debug mode - enables extra console logging
    debug: true
};

// Log configuration for debugging (after window is available)
if (typeof window !== 'undefined') {
    // Use setTimeout to ensure this runs after page load
    setTimeout(() => {
        if (CONFIG.debug) {
            console.log('[CONFIG] Environment:', detectProduction() ? 'PRODUCTION' : 'LOCAL');
            console.log('[CONFIG] Backend:', CONFIG.backend);
            console.log('[CONFIG] API Base URL:', CONFIG.apiBaseUrl);
            console.log('[CONFIG] Hostname:', window.location.hostname);
        }
    }, 100);
}

// Note: Can't freeze CONFIG because apiBaseUrl is a getter that needs to evaluate dynamically
