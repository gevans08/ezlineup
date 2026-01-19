/**
 * EZ Lineup Configuration
 * 
 * Change these settings to switch between backends:
 * - 'localStorage' : Data stored locally in browser (default, works offline)
 * - 'api'          : Data stored in Cloudflare D1 (requires internet, syncs across devices)
 */

const CONFIG = {
    // Storage backend: 'localStorage' or 'api'
    backend: 'localStorage',
    
    // API base URL (only used when backend is 'api')
    // - Use your deployed Cloudflare Worker URL for production
    // - Use 'http://localhost:8787' for local development with `wrangler dev`
    apiBaseUrl: 'https://ezlineup-api.jgraham-evans.workers.dev',
    
    // Debug mode - enables extra console logging
    debug: false
};

// Freeze the config to prevent accidental modifications
Object.freeze(CONFIG);
