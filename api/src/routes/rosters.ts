/**
 * Rosters Route Handler
 * Handles roster operations for a team
 */

import { Env } from '../index';

interface Roster {
  id: string;
  team_id: string;
  player_data: string;  // JSON string
  updated_at?: string;
}

interface Player {
  id: string;
  name: string;
  number?: string;
  position?: string;
  // Add any other player fields as needed
}

// Generate a unique ID
function generateId(): string {
  return `roster_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
}

/**
 * GET /api/teams/:teamId/roster - Get roster for a team
 */
export async function getRoster(env: Env, teamId: string): Promise<Response> {
  try {
    // Verify team exists
    const team = await env.DB.prepare(
      'SELECT id FROM teams WHERE id = ?'
    ).bind(teamId).first();

    if (!team) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    const roster = await env.DB.prepare(
      'SELECT * FROM rosters WHERE team_id = ?'
    ).bind(teamId).first<Roster>();

    if (!roster) {
      // Return empty roster if none exists
      return Response.json({
        roster: {
          team_id: teamId,
          players: [],
        }
      });
    }

    return Response.json({
      roster: {
        id: roster.id,
        team_id: roster.team_id,
        players: JSON.parse(roster.player_data),
        updated_at: roster.updated_at,
      }
    });
  } catch (error) {
    console.error('Error getting roster:', error);
    return Response.json({ error: 'Failed to get roster' }, { status: 500 });
  }
}

/**
 * PUT /api/teams/:teamId/roster - Update roster for a team (create if not exists)
 */
export async function updateRoster(env: Env, teamId: string, request: Request): Promise<Response> {
  try {
    // Verify team exists
    const team = await env.DB.prepare(
      'SELECT id FROM teams WHERE id = ?'
    ).bind(teamId).first();

    if (!team) {
      return Response.json({ error: 'Team not found' }, { status: 404 });
    }

    const body = await request.json() as { players: Player[] };

    if (!body.players || !Array.isArray(body.players)) {
      return Response.json(
        { error: 'Missing required field: players (array)' },
        { status: 400 }
      );
    }

    const now = new Date().toISOString();
    const playerData = JSON.stringify(body.players);

    // Check if roster exists
    const existing = await env.DB.prepare(
      'SELECT id FROM rosters WHERE team_id = ?'
    ).bind(teamId).first<Roster>();

    if (existing) {
      // Update existing roster
      await env.DB.prepare(
        'UPDATE rosters SET player_data = ?, updated_at = ? WHERE team_id = ?'
      ).bind(playerData, now, teamId).run();
    } else {
      // Create new roster
      const id = generateId();
      await env.DB.prepare(
        'INSERT INTO rosters (id, team_id, player_data, updated_at) VALUES (?, ?, ?, ?)'
      ).bind(id, teamId, playerData, now).run();
    }

    const roster = await env.DB.prepare(
      'SELECT * FROM rosters WHERE team_id = ?'
    ).bind(teamId).first<Roster>();

    return Response.json({
      roster: {
        id: roster?.id,
        team_id: teamId,
        players: body.players,
        updated_at: roster?.updated_at,
      }
    });
  } catch (error) {
    console.error('Error updating roster:', error);
    return Response.json({ error: 'Failed to update roster' }, { status: 500 });
  }
}
