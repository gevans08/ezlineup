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
-- SAMPLE GAMES
-- ============================================================================

-- Game 1: Vienna vs Mclean (Stats-only game from image)
-- Date: 12/20/2025
-- All 10 players participated (Playe: 1 for all)
INSERT INTO games (id, team_id, name, lineup, metadata, created_at, updated_at)
VALUES (
    'game_test_001',
    'team_test_002',  -- Vienna 6th team
    'vs Mclean - 12/20/2025',
    NULL,  -- Stats-only game, no lineup
    '{"opponent":"Mclean","gameDate":"2025-12-20","teamScore":null,"opponentScore":null,"comments":"","playerCount":10,"statsOnly":true,"statsPlayed":{"p1":true,"p2":true,"p3":true,"p4":true,"p5":true,"p6":true,"p7":true,"p8":true,"p9":true,"p10":true},"roster":[{"id":"p1","name":"Jackson","number":"25","present":true,"star":false,"positions":[1,2]},{"id":"p2","name":"Drew","number":"4","present":true,"star":false,"positions":[1,2]},{"id":"p3","name":"Rowan","number":"14","present":true,"star":false,"positions":[3,4]},{"id":"p4","name":"Owen","number":"2","present":true,"star":false,"positions":[3,4]},{"id":"p5","name":"Shaan","number":"24","present":true,"star":false,"positions":[5]},{"id":"p6","name":"James","number":"1","present":true,"star":false,"positions":[1,2]},{"id":"p7","name":"Max","number":"30","present":true,"star":false,"positions":[3,4]},{"id":"p8","name":"Flynn","number":"5","present":true,"star":false,"positions":[3,4]},{"id":"p9","name":"Callen","number":"10","present":true,"star":false,"positions":[5]},{"id":"p10","name":"Leo","number":"22","present":true,"star":false,"positions":[1,2]}],"playerStats":{"p1":{"points":12,"assists":0,"rebounds":8,"blocks":3,"steals":0,"turnovers":0},"p2":{"points":9,"assists":0,"rebounds":1,"blocks":1,"steals":2,"turnovers":1},"p3":{"points":5,"assists":0,"rebounds":5,"blocks":0,"steals":1,"turnovers":2},"p4":{"points":0,"assists":0,"rebounds":7,"blocks":1,"steals":2,"turnovers":0},"p5":{"points":4,"assists":0,"rebounds":1,"blocks":0,"steals":2,"turnovers":1},"p6":{"points":2,"assists":0,"rebounds":11,"blocks":0,"steals":4,"turnovers":4},"p7":{"points":5,"assists":0,"rebounds":1,"blocks":0,"steals":2,"turnovers":3},"p8":{"points":0,"assists":0,"rebounds":0,"blocks":0,"steals":0,"turnovers":0},"p9":{"points":0,"assists":0,"rebounds":2,"blocks":0,"steals":0,"turnovers":0},"p10":{"points":0,"assists":0,"rebounds":0,"blocks":0,"steals":0,"turnovers":0}},"savedAt":"2025-12-20T00:00:00.000Z"}',
    datetime('now'),
    datetime('now')
);
