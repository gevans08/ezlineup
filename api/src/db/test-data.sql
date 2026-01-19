-- EZLineup Test Data
-- Edit the team names, player names, and numbers below, then run:
-- wrangler d1 execute ezlineup-db --local --file=./src/db/test-data.sql

-- ============================================================================
-- CLEAR EXISTING DATA (Optional - uncomment if you want to start fresh)
-- ============================================================================
-- DELETE FROM games;
-- DELETE FROM rosters;
-- DELETE FROM teams;

-- ============================================================================
-- TEAM 1: Edit team name, sport, league, season below
-- ============================================================================
INSERT OR REPLACE INTO teams (id, name, sport, league, season, archived, created_at, updated_at)
VALUES (
    'team_test_001',
    'Blue Devils',  -- EDIT: Change team name here
    'Basketball',   -- EDIT: Change sport if needed
    'Youth League', -- EDIT: Change league name
    '2026',         -- EDIT: Change season
    0,
    datetime('now'),
    datetime('now')
);

-- Team 1 Roster: Edit player names and numbers below
-- 
-- To edit players, replace the JSON array below. Each player needs:
--   - "id": unique ID (p1, p2, etc.)
--   - "name": player's name
--   - "number": jersey number (as string)
--   - "position": Guard, Forward, or Center (optional, for reference)
--   - "positions": array of numbers [1,2,3,4,5] representing court positions
--
-- Example readable format (must be on ONE line in SQL):
-- [{"id":"p1","name":"John Smith","number":"10","position":"Guard","positions":[1,2]},
--  {"id":"p2","name":"Jane Doe","number":"5","position":"Forward","positions":[3,4]}, ...]
--
INSERT OR REPLACE INTO rosters (id, team_id, player_data, updated_at)
VALUES (
    'roster_test_001',
    'team_test_001',
    '[{"id":"p1","name":"Noah","number":"1","position":"Guard","positions":[1,2]},{"id":"p2","name":"Reyansh","number":"2","position":"Guard","positions":[1,2]},{"id":"p3","name":"Colin","number":"3","position":"Forward","positions":[3,4]},{"id":"p4","name":"John","number":"4","position":"Forward","positions":[3,4]},{"id":"p5","name":"Iskandar","number":"5","position":"Center","positions":[5]},{"id":"p6","name":"Arjun","number":"6","position":"Guard","positions":[1,2]},{"id":"p7","name":"Jacob O","number":"7","position":"Forward","positions":[3,4]},{"id":"p8","name":"Spancer","number":"8","position":"Forward","positions":[3,4]},{"id":"p9","name":"Aarav","number":"9","position":"Center","positions":[5]},{"id":"p10","name":"Jacob S","number":"10","position":"Guard","positions":[1,2]}]',
    datetime('now')
);

-- ============================================================================
-- TEAM 2: Edit team name, sport, league, season below
-- ============================================================================
INSERT OR REPLACE INTO teams (id, name, sport, league, season, archived, created_at, updated_at)
VALUES (
    'team_test_002',
    'Vienna 6th',    -- EDIT: Change team name here
    'Basketball',   -- EDIT: Change sport if needed
    'Vienna Select 6th', -- EDIT: Change league name
    '2026',         -- EDIT: Change season
    0,
    datetime('now'),
    datetime('now')
);

-- Team 2 Roster: Edit player names and numbers below
-- 
-- To edit players, replace the JSON array below. Each player needs:
--   - "id": unique ID (p1, p2, etc.)
--   - "name": player's name
--   - "number": jersey number (as string)
--   - "position": Guard, Forward, or Center (optional, for reference)
--   - "positions": array of numbers [1,2,3,4,5] representing court positions
--
-- Example readable format (must be on ONE line in SQL):
-- [{"id":"p1","name":"John Smith","number":"10","position":"Guard","positions":[1,2]},
--  {"id":"p2","name":"Jane Doe","number":"5","position":"Forward","positions":[3,4]}, ...]
--
INSERT OR REPLACE INTO rosters (id, team_id, player_data, updated_at)
VALUES (
    'roster_test_002',
    'team_test_002',
    '[{"id":"p1","name":"Jackson","number":"25","position":"Guard","positions":[1,2]},{"id":"p2","name":"Drew","number":"4","position":"Guard","positions":[1,2]},{"id":"p3","name":"Rowan","number":"14","position":"Forward","positions":[3,4]},{"id":"p4","name":"Owen","number":"2","position":"Forward","positions":[3,4]},{"id":"p5","name":"Shaan","number":"24","position":"Center","positions":[5]},{"id":"p6","name":"James","number":"1","position":"Guard","positions":[1,2]},{"id":"p7","name":"Max","number":"30","position":"Forward","positions":[3,4]},{"id":"p8","name":"Flynn","number":"5","position":"Forward","positions":[3,4]},{"id":"p9","name":"Callen","number":"10","position":"Center","positions":[5]},{"id":"p10","name":"Leo","number":"22","position":"Guard","positions":[1,2]}]',
    datetime('now')
);

-- ============================================================================
-- OPTIONAL: Add sample games (uncomment and edit if you want test games)
-- ============================================================================
-- INSERT INTO games (id, team_id, name, lineup, metadata, created_at, updated_at)
-- VALUES (
--     'game_test_001',
--     'team_test_001',
--     'vs Red Hawks - Jan 20, 2026',
--     NULL,  -- No lineup yet
--     '{"opponent":"Red Hawks","date":"2026-01-20","teamScore":0,"opponentScore":0}',
--     datetime('now'),
--     datetime('now')
-- );
