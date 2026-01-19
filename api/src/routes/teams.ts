/**
 * Teams Route Handler
 * Handles CRUD operations for teams
 */

import { Env } from '../index';

interface Team {
  id: string;
  name: string;
  sport: string;
  league?: string;
  season?: string;
  archived?: number;
  created_at?: string;
  updated_at?: string;
}

// Generate a unique ID
function generateId(): string {
  return `team_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * GET /api/teams - List all teams
 */
export async function listTeams(env: Env): Promise<Response> {
  try {
    const { results } = await env.DB.prepare(
      'SELECT * FROM teams WHERE archived = 0 ORDER BY created_at DESC'
    ).all<Team>();

    return Response.json({ teams: results || [] });
  } catch (error) {
    console.error('Error listing teams:', error);
    return Response.json({ error: 'Failed to list teams' }, { status: 500 });
  }
}

/**
 * GET /api/teams/:id - Get a single team
 */
export async function getTeam(env: Env, teamId: string): Promise<Response> {
  try {
    const team = await env.DB.prepare(
      'SELECT * FROM teams WHERE id = ?'
    ).bind(teamId).first<Team>();

    if (!team) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    return Response.json({ team });
  } catch (error) {
    console.error('Error getting team:', error);
    return Response.json({ error: 'Failed to get team' }, { status: 500 });
  }
}

/**
 * POST /api/teams - Create a new team
 */
export async function createTeam(env: Env, request: Request): Promise<Response> {
  try {
    const body = await request.json() as Partial<Team>;

    if (!body.name || !body.sport) {
      return Response.json(
        { error: 'Missing required fields: name, sport' },
        { status: 400 }
      );
    }

    const id = body.id || generateId();
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO teams (id, name, sport, league, season, archived, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 0, ?, ?)`
    ).bind(
      id,
      body.name,
      body.sport,
      body.league || null,
      body.season || null,
      now,
      now
    ).run();

    const team = await env.DB.prepare(
      'SELECT * FROM teams WHERE id = ?'
    ).bind(id).first<Team>();

    return Response.json({ team }, { status: 201 });
  } catch (error) {
    console.error('Error creating team:', error);
    return Response.json({ error: 'Failed to create team' }, { status: 500 });
  }
}

/**
 * PUT /api/teams/:id - Update a team
 */
export async function updateTeam(env: Env, teamId: string, request: Request): Promise<Response> {
  try {
    // Check if team exists
    const existing = await env.DB.prepare(
      'SELECT * FROM teams WHERE id = ?'
    ).bind(teamId).first<Team>();

    if (!existing) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    const body = await request.json() as Partial<Team>;
    const now = new Date().toISOString();

    await env.DB.prepare(
      `UPDATE teams 
       SET name = ?, sport = ?, league = ?, season = ?, archived = ?, updated_at = ?
       WHERE id = ?`
    ).bind(
      body.name ?? existing.name,
      body.sport ?? existing.sport,
      body.league ?? existing.league ?? null,
      body.season ?? existing.season ?? null,
      body.archived ?? existing.archived ?? 0,
      now,
      teamId
    ).run();

    const team = await env.DB.prepare(
      'SELECT * FROM teams WHERE id = ?'
    ).bind(teamId).first<Team>();

    return Response.json({ team });
  } catch (error) {
    console.error('Error updating team:', error);
    return Response.json({ error: 'Failed to update team' }, { status: 500 });
  }
}

/**
 * DELETE /api/teams/:id - Archive a team (soft delete)
 */
export async function deleteTeam(env: Env, teamId: string): Promise<Response> {
  try {
    const existing = await env.DB.prepare(
      'SELECT * FROM teams WHERE id = ?'
    ).bind(teamId).first<Team>();

    if (!existing) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    // Soft delete by setting archived = 1
    await env.DB.prepare(
      'UPDATE teams SET archived = 1, updated_at = ? WHERE id = ?'
    ).bind(new Date().toISOString(), teamId).run();

    return Response.json({ success: true, message: 'Team archived' });
  } catch (error) {
    console.error('Error deleting team:', error);
    return Response.json({ error: 'Failed to delete team' }, { status: 500 });
  }
}
