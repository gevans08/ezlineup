export type Team = {
  id: string;
  family_id: string;
  name: string;
  sport: string;
  league: string | null;
  season: string | null;
};

export type Player = {
  id: string;
  team_id: string;
  family_id: string;
  name: string;
  number: string | null;
  active: boolean;
  sort_order: number;
};

export type StatLine = {
  id: string;
  game_id: string;
  player_id: string;
  family_id: string;
  points: number;
  rebounds: number;
  assists: number;
  steals: number;
  blocks: number;
  turnovers: number;
  fouls: number;
  on_court: boolean;
};

export type Game = {
  id: string;
  team_id: string;
  family_id: string;
  opponent: string;
  game_date: string;
  team_score: number;
  opponent_score: number;
  status: "live" | "final";
  period: number;
  comments: string;
  score_player_stats?: StatLine[];
};

export type StatKey =
  | "points2"
  | "points3"
  | "ft"
  | "reb"
  | "ast"
  | "stl"
  | "blk"
  | "to"
  | "foul";
