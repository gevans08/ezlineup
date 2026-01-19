/**
 * Games Route Handler
 * Handles CRUD operations for games within a team
 */

import { Env } from '../index';

interface Game {
  id: string;
  team_id: string;
  name: string;
  lineup?: string;      // JSON string
  metadata: string;     // JSON string
  created_at?: string;
  updated_at?: string;
}

interface GameInput {
  id?: string;
  name: string;
  lineup?: object;
  metadata?: object;
}

// Generate a unique ID
function generateId(): string {
  return `game_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * GET /api/teams/:teamId/games - List all games for a team
 */
export async function listGames(env: Env, teamId: string): Promise<Response> {
  try {
    // Verify team exists
    const team = await env.DB.prepare(
      'SELECT id FROM teams WHERE id = ?'
    ).bind(teamId).first();

    if (!team) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    const { results } = await env.DB.prepare(
      'SELECT * FROM games WHERE team_id = ? ORDER BY created_at DESC'
    ).bind(teamId).all<Game>();

    // Parse JSON fields for each game
    const games = (results || []).map(game => ({
      ...game,
      lineup: game.lineup ? JSON.parse(game.lineup) : null,
      metadata: game.metadata ? JSON.parse(game.metadata) : {},
    }));

    return Response.json({ games });
  } catch (error) {
    console.error('Error listing games:', error);
    return Response.json({ error: 'Failed to list games' }, { status: 500 });
  }
}

/**
 * GET /api/teams/:teamId/games/:gameId - Get a single game
 */
export async function getGame(env: Env, teamId: string, gameId: string): Promise<Response> {
  try {
    const game = await env.DB.prepare(
      'SELECT * FROM games WHERE id = ? AND team_id = ?'
    ).bind(gameId, teamId).first<Game>();

    if (!game) {
      return Response.json({ error: 'Game not found' }, { status: 404 });
    }

    return Response.json({
      game: {
        ...game,
        lineup: game.lineup ? JSON.parse(game.lineup) : null,
        metadata: game.metadata ? JSON.parse(game.metadata) : {},
      }
    });
  } catch (error) {
    console.error('Error getting game:', error);
    return Response.json({ error: 'Failed to get game' }, { status: 500 });
  }
}

/**
 * POST /api/teams/:teamId/games - Create a new game
 */
export async function createGame(env: Env, teamId: string, request: Request): Promise<Response> {
  try {
    // Verify team exists
    const team = await env.DB.prepare(
      'SELECT id FROM teams WHERE id = ?'
    ).bind(teamId).first();

    if (!team) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    const body = await request.json() as GameInput;

    if (!body.name) {
      return Response.json(
        { error: 'Missing required field: name' },
        { status: 400 }
      );
    }

    const id = body.id || generateId();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO games (id, team_id, name, lineup, metadata, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      id,
      teamId,
      body.name,
      body.lineup ? JSON.stringify(body.lineup) : null,
      JSON.stringify(body.metadata || {}),
      now,
      now
    ).run();

    const game = await env.DB.prepare(
      'SELECT * FROM games WHERE id = ?'
    ).bind(id).first<Game>();

    return Response.json({
      game: {
        ...game,
        lineup: game?.lineup ? JSON.parse(game.lineup) : null,
        metadata: game?.metadata ? JSON.parse(game.metadata) : {},
      }
    }, { status: 201 });
  } catch (error) {
    console.error('Error creating game:', error);
    return Response.json({ error: 'Failed to create game' }, { status: 500 });
  }
}

/**
 * PUT /api/teams/:teamId/games/:gameId - Update a game
 */
export async function updateGame(
  env: Env,
  teamId: string,
  gameId: string,
  request: Request
): Promise<Response> {
  try {
    const existing = await env.DB.prepare(
      'SELECT * FROM games WHERE id = ? AND team_id = ?'
    ).bind(gameId, teamId).first<Game>();

    if (!existing) {
      return Response.json({ error: 'Game not found' }, { status: 404 });
    }

    const body = await request.json() as Partial<GameInput>;
    const now = new Date().toISOString();

    // Merge existing metadata with new metadata if provided
    const existingMetadata = existing.metadata ? JSON.parse(existing.metadata) : {};
    const newMetadata = body.metadata ? { ...existingMetadata, ...body.metadata } : existingMetadata;

    await env.DB.prepare(
      `UPDATE games 
       SET name = ?, lineup = ?, metadata = ?, updated_at = ?
       WHERE id = ? AND team_id = ?`
    ).bind(
      body.name ?? existing.name,
      body.lineup !== undefined ? JSON.stringify(body.lineup) : existing.lineup,
      JSON.stringify(newMetadata),
      now,
      gameId,
      teamId
    ).run();

    const game = await env.DB.prepare(
      'SELECT * FROM games WHERE id = ?'
    ).bind(gameId).first<Game>();

    return Response.json({
      game: {
        ...game,
        lineup: game?.lineup ? JSON.parse(game.lineup) : null,
        metadata: game?.metadata ? JSON.parse(game.metadata) : {},
      }
    });
  } catch (error) {
    console.error('Error updating game:', error);
    return Response.json({ error: 'Failed to update game' }, { status: 500 });
  }
}

/**
 * DELETE /api/teams/:teamId/games/:gameId - Delete a game
 */
export async function deleteGame(env: Env, teamId: string, gameId: string): Promise<Response> {
  try {
    const existing = await env.DB.prepare(
      'SELECT * FROM games WHERE id = ? AND team_id = ?'
    ).bind(gameId, teamId).first<Game>();

    if (!existing) {
      return Response.json({ error: 'Game not found' }, { status: 404 });
    }

    await env.DB.prepare(
      'DELETE FROM games WHERE id = ? AND team_id = ?'
    ).bind(gameId, teamId).run();

    return Response.json({ success: true, message: 'Game deleted' });
  } catch (error) {
    console.error('Error deleting game:', error);
    return Response.json({ error: 'Failed to delete game' }, { status: 500 });
  }
}
