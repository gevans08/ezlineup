export type Score = {
  team_score: number;
  opponent_score: number;
};

export type Record = {
  wins: number;
  losses: number;
  ties: number;
};

export function seasonRecord(games: Score[]): Record {
  const record = { wins: 0, losses: 0, ties: 0 };
  for (const game of games) {
    if (game.team_score > game.opponent_score) record.wins += 1;
    else if (game.team_score < game.opponent_score) record.losses += 1;
    else record.ties += 1;
  }
  return record;
}

export function recordLabel(record: Record): string {
  if (record.ties > 0) return `${record.wins}–${record.losses}–${record.ties}`;
  return `${record.wins}–${record.losses}`;
}

export function formatGameDate(iso: string): string {
  const [year, month, day] = iso.split("-").map(Number);
  return new Date(year, month - 1, day).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function periodLabel(period: number): string {
  if (period >= 5) return "OT";
  return `Q${period}`;
}
