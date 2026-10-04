-- EZ Lineup scoring tables in the Field Commander Supabase project.
-- Separate from Field Commander tables. Visible only to the signed-in family.

create table if not exists public.score_teams (
  id uuid primary key,
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  sport text not null default 'basketball',
  league text,
  season text,
  created_at timestamptz not null default now()
);
create table if not exists public.score_players (
  id uuid primary key,
  team_id uuid not null references public.score_teams(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  name text not null,
  number text,
  active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table if not exists public.score_games (
  id uuid primary key,
  team_id uuid not null references public.score_teams(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  opponent text not null,
  game_date date not null,
  team_score integer not null default 0,
  opponent_score integer not null default 0,
  status text not null default 'final' check (status in ('live','final')),
  period integer not null default 1 check (period between 1 and 5),
  comments text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.score_player_stats (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.score_games(id) on delete cascade,
  player_id uuid not null references public.score_players(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  points integer not null default 0,
  rebounds integer not null default 0,
  assists integer not null default 0,
  steals integer not null default 0,
  blocks integer not null default 0,
  turnovers integer not null default 0,
  fouls integer not null default 0,
  on_court boolean not null default false,
  unique (game_id, player_id)
);
create index if not exists score_teams_family_idx on public.score_teams (family_id);
create index if not exists score_players_team_idx on public.score_players (team_id, sort_order);
create index if not exists score_players_family_idx on public.score_players (family_id);
create index if not exists score_games_team_date_idx on public.score_games (team_id, game_date desc);
create index if not exists score_games_family_idx on public.score_games (family_id);
create index if not exists score_player_stats_game_idx on public.score_player_stats (game_id);
create index if not exists score_player_stats_family_idx on public.score_player_stats (family_id);
alter table public.score_teams enable row level security;
alter table public.score_players enable row level security;
alter table public.score_games enable row level security;
alter table public.score_player_stats enable row level security;
drop policy if exists score_teams_family_all on public.score_teams;
create policy score_teams_family_all on public.score_teams
  for all to authenticated
  using (family_id = public.get_my_family_id())
  with check (family_id = public.get_my_family_id());
grant select, insert, update, delete on public.score_teams to authenticated;
drop policy if exists score_players_family_all on public.score_players;
create policy score_players_family_all on public.score_players
  for all to authenticated
  using (family_id = public.get_my_family_id())
  with check (family_id = public.get_my_family_id());
grant select, insert, update, delete on public.score_players to authenticated;
drop policy if exists score_games_family_all on public.score_games;
create policy score_games_family_all on public.score_games
  for all to authenticated
  using (family_id = public.get_my_family_id())
  with check (family_id = public.get_my_family_id());
grant select, insert, update, delete on public.score_games to authenticated;
drop policy if exists score_player_stats_family_all on public.score_player_stats;
create policy score_player_stats_family_all on public.score_player_stats
  for all to authenticated
  using (family_id = public.get_my_family_id())
  with check (family_id = public.get_my_family_id());
grant select, insert, update, delete on public.score_player_stats to authenticated;

create or replace function public.score_apply_event(
  p_game_id uuid,
  p_side text,
  p_player_id uuid,
  p_stat text,
  p_direction integer
) returns void
language plpgsql
security invoker
set search_path = public
as $fn$
declare
  g public.score_games;
  delta integer;
begin
  if p_direction not in (-1, 1) then
    raise exception 'invalid direction';
  end if;
  select * into g from public.score_games where id = p_game_id;
  if not found then
    raise exception 'game not found';
  end if;
  if g.status <> 'live' then
    raise exception 'game is final';
  end if;
  if g.family_id is distinct from public.get_my_family_id() then
    raise exception 'not allowed';
  end if;

  if p_side = 'them' then
    delta := case p_stat when 'points2' then 2 when 'points3' then 3 when 'ft' then 1 else 0 end;
    if delta = 0 then
      raise exception 'opponent stat not supported';
    end if;
    update public.score_games
      set opponent_score = greatest(0, opponent_score + delta * p_direction),
          updated_at = now()
      where id = p_game_id;
    return;
  end if;

  if p_side <> 'us' or p_player_id is null then
    raise exception 'player required';
  end if;

  insert into public.score_player_stats (game_id, player_id, family_id)
  values (p_game_id, p_player_id, g.family_id)
  on conflict (game_id, player_id) do nothing;

  if p_stat = 'points2' then
    update public.score_player_stats set points = greatest(0, points + 2 * p_direction)
      where game_id = p_game_id and player_id = p_player_id;
    update public.score_games set team_score = greatest(0, team_score + 2 * p_direction), updated_at = now()
      where id = p_game_id;
  elsif p_stat = 'points3' then
    update public.score_player_stats set points = greatest(0, points + 3 * p_direction)
      where game_id = p_game_id and player_id = p_player_id;
    update public.score_games set team_score = greatest(0, team_score + 3 * p_direction), updated_at = now()
      where id = p_game_id;
  elsif p_stat = 'ft' then
    update public.score_player_stats set points = greatest(0, points + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
    update public.score_games set team_score = greatest(0, team_score + p_direction), updated_at = now()
      where id = p_game_id;
  elsif p_stat = 'reb' then
    update public.score_player_stats set rebounds = greatest(0, rebounds + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
  elsif p_stat = 'ast' then
    update public.score_player_stats set assists = greatest(0, assists + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
  elsif p_stat = 'stl' then
    update public.score_player_stats set steals = greatest(0, steals + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
  elsif p_stat = 'blk' then
    update public.score_player_stats set blocks = greatest(0, blocks + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
  elsif p_stat = 'to' then
    update public.score_player_stats set turnovers = greatest(0, turnovers + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
  elsif p_stat = 'foul' then
    update public.score_player_stats set fouls = greatest(0, fouls + p_direction)
      where game_id = p_game_id and player_id = p_player_id;
  else
    raise exception 'unknown stat';
  end if;
end;
$fn$;
revoke all on function public.score_apply_event(uuid, text, uuid, text, integer) from public;
revoke all on function public.score_apply_event(uuid, text, uuid, text, integer) from anon;
grant execute on function public.score_apply_event(uuid, text, uuid, text, integer) to authenticated;

insert into public.score_teams (id, family_id, name, sport, league, season)
values ('61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Vienna 6th', 'basketball', 'Vienna Select 6th', '2026')
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Jackson', '25', 0)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('67482d5e-61c7-5e9d-841f-4a5bd0386577', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Drew', '4', 1)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('58d10b54-e7f7-556d-9af9-c9876143f369', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Rowan', '14', 2)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('2251f9c0-9b6c-5728-983c-d623d74292eb', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Owen', '2', 3)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Shaan', '24', 4)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('34aa9241-59be-5332-b184-ce3c762ea2fc', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'James', '1', 5)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('07cf5f4b-b4db-5793-945b-7ca64af20d2c', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Max', '30', 6)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('27508f57-8a15-50ee-8f9d-d40b80ee6021', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Flynn', '5', 7)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Callen', '10', 8)
on conflict (id) do nothing;
insert into public.score_players (id, team_id, family_id, name, number, sort_order)
values ('e01d5958-c2aa-5631-8f93-e1db9a0cd491', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Leo', '22', 9)
on conflict (id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Mclean', '2025-12-20', 37, 26, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 12, 8, 0, 3, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 9, 1, 0, 2, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 5, 0, 1, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 7, 0, 2, 1, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 1, 0, 2, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 11, 0, 4, 0, 4)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 1, 0, 2, 0, 3)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 2, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('0c9a4495-11cc-54d8-b749-ed2b08d00de3', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Alexandria', '2026-01-10', 41, 46, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 8, 6, 0, 4, 2, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 0, 1, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 1, 1, 4, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 11, 5, 1, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 1, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 0, 0, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 1, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9a09e6fd-428b-5abe-91ba-6dabe61d42f1', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Gum Springs', '2026-01-11', 54, 49, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 11, 15, 0, 2, 2, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 9, 0, 1, 2, 0, 5)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 7, 1, 0, 1, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 9, 6, 0, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 7, 0, 1, 3, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 1, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 3, 0, 1, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 2, 0, 1, 4, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('9d5e1950-f04e-5813-a5b8-c4277038eb36', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 4, 0, 0, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Gum Springs 2', '2026-01-18', 68, 40, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 11, 6, 1, 3, 4, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 6, 1, 1, 2, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 10, 2, 0, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 6, 0, 0, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 9, 2, 0, 1, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 12, 1, 1, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 2, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 0, 0, 1, 1, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 2, 0, 2, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('a0824920-7813-5824-a74f-4d99f6c604fd', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 3, 0, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Arlington', '2026-01-24', 31, 31, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 6, 11, 0, 4, 2, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 5, 0, 1, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 3, 1, 1, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 0, 2, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 1, 0, 1, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 10, 3, 0, 1, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 6, 1, 0, 0, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('65241349-87f2-5eed-ae02-8fadbd71d39e', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 1, 0, 0, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'CYA', '2026-01-31', 45, 41, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 9, 3, 0, 2, 4, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 3, 1, 2, 1, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 5, 1, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 11, 2, 0, 1, 3, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 2, 2, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 1, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 7, 0, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 8, 2, 0, 2, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 0, 1, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('b860a116-716d-599d-96a3-35d8a755e4a8', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 1, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Arlington', '2026-02-01', 50, 37, 'final', 'James had some good plays. Needs to finish.')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 4, 0, 5, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 16, 4, 2, 1, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 11, 6, 1, 1, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 1, 2, 2, 1, 4)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 6, 0, 0, 1, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '34aa9241-59be-5332-b184-ce3c762ea2fc', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 2, 1, 1, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 1, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 8, 3, 0, 5, 1, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('d5229d04-082f-5e02-9d3f-73064a83463d', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 0, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_games (id, team_id, family_id, opponent, game_date, team_score, opponent_score, status, comments)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '61e904bf-f1c6-5376-8cfc-168ebe22bf42', '178d1935-d4b3-4e96-942d-a368f502a88c', 'Alexandria (championship)', '2026-03-07', 25, 43, 'final', '')
on conflict (id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', 'fd8711e4-0b7d-5525-9ec5-9b20df0c07a5', '178d1935-d4b3-4e96-942d-a368f502a88c', 4, 2, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '67482d5e-61c7-5e9d-841f-4a5bd0386577', '178d1935-d4b3-4e96-942d-a368f502a88c', 5, 1, 2, 3, 0, 4)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '58d10b54-e7f7-556d-9af9-c9876143f369', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 2, 1, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '2251f9c0-9b6c-5728-983c-d623d74292eb', '178d1935-d4b3-4e96-942d-a368f502a88c', 8, 3, 0, 0, 0, 1)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', 'e0c63e40-363b-5fd2-bcbc-0ebde4b99c49', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 2, 2, 2, 1, 3)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '07cf5f4b-b4db-5793-945b-7ca64af20d2c', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 1, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '27508f57-8a15-50ee-8f9d-d40b80ee6021', '178d1935-d4b3-4e96-942d-a368f502a88c', 3, 0, 0, 0, 0, 0)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', '8fa8fcf7-6a08-599e-83ae-8524b6c7cc9e', '178d1935-d4b3-4e96-942d-a368f502a88c', 2, 1, 0, 0, 0, 2)
on conflict (game_id, player_id) do nothing;
insert into public.score_player_stats (game_id, player_id, family_id, points, rebounds, assists, steals, blocks, turnovers)
values ('f1730b51-e55b-5d8b-b5e6-81d7c13321b0', 'e01d5958-c2aa-5631-8f93-e1db9a0cd491', '178d1935-d4b3-4e96-942d-a368f502a88c', 0, 0, 0, 0, 0, 1)
on conflict (game_id, player_id) do nothing;
