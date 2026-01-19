/**
 * EZLineup API - Cloudflare Worker
 *
 * This worker handles all API requests for the EZLineup application.
 * It connects to a D1 database for persistent storage.
 */

// Route handlers
import { listTeams, getTeam, createTeam, updateTeam, deleteTeam } from './routes/teams';
import { listGames, getGame, createGame, updateGame, deleteGame } from './routes/games';
import { getRoster, updateRoster } from './routes/rosters';

export interface Env {
  DB: D1Database;
}

// CORS headers for cross-origin requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

// Helper to add CORS headers to any response
function withCors(response: Response): Response {
  const newHeaders = new Headers(response.headers);
  Object.entries(corsHeaders).forEach(([key, value]) => {
    newHeaders.set(key, value);
  });
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers: newHeaders,
  });
}

// Simple URL pattern matcher
function matchRoute(pathname: string, pattern: string): Record<string, string> | null {
  const patternParts = pattern.split('/');
  const pathParts = pathname.split('/');

  if (patternParts.length !== pathParts.length) {
    return null;
  }

  const params: Record<string, string> = {};

  for (let i = 0; i < patternParts.length; i++) {
    const patternPart = patternParts[i];
    const pathPart = pathParts[i];

    if (patternPart.startsWith(':')) {
      // This is a parameter
      params[patternPart.slice(1)] = pathPart;
    } else if (patternPart !== pathPart) {
      // Literal parts don't match
      return null;
    }
  }

  return params;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // Handle CORS preflight requests
    if (method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      let response: Response;

      // Health check endpoint
      if (path === '/api/health' && method === 'GET') {
        response = Response.json({
          status: 'ok',
          message: 'EZLineup API is running!',
          timestamp: new Date().toISOString(),
        });
        return withCors(response);
      }

      // ============ TEAMS ROUTES ============

      // GET /api/teams - List all teams
      if (path === '/api/teams' && method === 'GET') {
        response = await listTeams(env);
        return withCors(response);
      }

      // POST /api/teams - Create a team
      if (path === '/api/teams' && method === 'POST') {
        response = await createTeam(env, request);
        return withCors(response);
      }

      // GET /api/teams/:teamId - Get a single team
      let params = matchRoute(path, '/api/teams/:teamId');
      if (params && method === 'GET' && !path.includes('/games') && !path.includes('/roster')) {
        response = await getTeam(env, params.teamId);
        return withCors(response);
      }

      // PUT /api/teams/:teamId - Update a team
      params = matchRoute(path, '/api/teams/:teamId');
      if (params && method === 'PUT' && !path.includes('/games') && !path.includes('/roster')) {
        response = await updateTeam(env, params.teamId, request);
        return withCors(response);
      }

      // DELETE /api/teams/:teamId - Archive a team
      params = matchRoute(path, '/api/teams/:teamId');
      if (params && method === 'DELETE' && !path.includes('/games') && !path.includes('/roster')) {
        response = await deleteTeam(env, params.teamId);
        return withCors(response);
      }

      // ============ GAMES ROUTES ============

      // GET /api/teams/:teamId/games - List all games for a team
      params = matchRoute(path, '/api/teams/:teamId/games');
      if (params && method === 'GET') {
        response = await listGames(env, params.teamId);
        return withCors(response);
      }

      // POST /api/teams/:teamId/games - Create a game
      params = matchRoute(path, '/api/teams/:teamId/games');
      if (params && method === 'POST') {
        response = await createGame(env, params.teamId, request);
        return withCors(response);
      }

      // GET /api/teams/:teamId/games/:gameId - Get a single game
      params = matchRoute(path, '/api/teams/:teamId/games/:gameId');
      if (params && method === 'GET') {
        response = await getGame(env, params.teamId, params.gameId);
        return withCors(response);
      }

      // PUT /api/teams/:teamId/games/:gameId - Update a game
      params = matchRoute(path, '/api/teams/:teamId/games/:gameId');
      if (params && method === 'PUT') {
        response = await updateGame(env, params.teamId, params.gameId, request);
        return withCors(response);
      }

      // DELETE /api/teams/:teamId/games/:gameId - Delete a game
      params = matchRoute(path, '/api/teams/:teamId/games/:gameId');
      if (params && method === 'DELETE') {
        response = await deleteGame(env, params.teamId, params.gameId);
        return withCors(response);
      }

      // ============ ROSTER ROUTES ============

      // GET /api/teams/:teamId/roster - Get roster for a team
      params = matchRoute(path, '/api/teams/:teamId/roster');
      if (params && method === 'GET') {
        response = await getRoster(env, params.teamId);
        return withCors(response);
      }

      // PUT /api/teams/:teamId/roster - Update roster for a team
      params = matchRoute(path, '/api/teams/:teamId/roster');
      if (params && method === 'PUT') {
        response = await updateRoster(env, params.teamId, request);
        return withCors(response);
      }

      // ============ 404 NOT FOUND ============
      response = Response.json(
        { error: 'Not found', path, method },
        { status: 404 }
      );
      return withCors(response);

    } catch (error) {
      console.error('Unhandled error:', error);
      const response = Response.json(
        { error: 'Internal server error' },
        { status: 500 }
      );
      return withCors(response);
    }
  },
};
