/**
 * EZ Lineup Configuration
 * 
 * Change these settings to switch between backends:
 * - 'localStorage' : Data stored locally in browser (default, works offline)
 * - 'api'          : Data stored in Cloudflare D1 (requires internet, syncs across devices)
 */

// Auto-detect environment: production or local development
const isProduction = typeof window !== 'undefined' && 
    (window.location.hostname.includes('pages.dev') || 
     window.location.hostname.includes('ezlineup') ||
     (window.location.hostname !== 'localhost' && window.location.hostname !== '127.0.0.1'));

const CONFIG = {
    // Storage backend: 'localStorage' or 'api'
    backend: 'api',
    
    // API base URL (only used when backend is 'api')
    // - Automatically uses production URL when deployed
    // - Uses localhost for local development
    apiBaseUrl: isProduction 
        ? 'https://ezlineup-api.jgraham-evans.workers.dev'
        : 'http://localhost:8787',
    
    // Debug mode - enables extra console logging
    debug: true
};

// Log configuration for debugging
if (CONFIG.debug && typeof window !== 'undefined') {
    console.log('[CONFIG] Environment:', isProduction ? 'PRODUCTION' : 'LOCAL');
    console.log('[CONFIG] Backend:', CONFIG.backend);
    console.log('[CONFIG] API Base URL:', CONFIG.apiBaseUrl);
    console.log('[CONFIG] Hostname:', window.location.hostname);
}

// Freeze the config to prevent accidental modifications
Object.freeze(CONFIG);
