import { FormEvent, useEffect, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { getSupabase, supabase, supabaseConfigured } from "./lib/supabase";
import type { Game, Player, StatKey, Team } from "./lib/types";
import { formatGameDate, periodLabel, recordLabel, seasonRecord } from "./lib/season";

type Tab = "season" | "roster" | "score";

export function App() {
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!supabase) {
      setReady(true);
      return;
    }
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      setReady(true);
    });
    const { data } = supabase.auth.onAuthStateChange((_event, next) => {
      setSession(next);
    });
    return () => data.subscription.unsubscribe();
  }, []);

  if (!supabaseConfigured || !supabase) {
    return (
      <main className="app">
        <p className="eyebrow">EZ Lineup</p>
        <h1>Setup needed</h1>
        <p className="center-note">
          Add the Supabase URL and publishable key in web/.env.local, then restart the app.
        </p>
      </main>
    );
  }

  if (!ready) {
    return (
      <main className="app">
        <p className="sub">Loading</p>
      </main>
    );
  }

  if (!session) return <SignIn />;
  return <Court onSignOut={() => getSupabase().auth.signOut()} />;
}

function SignIn() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const { error: signInError } = await getSupabase().auth.signInWithPassword({ email, password });
    setBusy(false);
    if (signInError) setError(signInError.message);
  }

  return (
    <main className="app sign-in">
      <p className="eyebrow">EZ Lineup</p>
      <h1>Sign in</h1>
      <p className="sub">Use the same email and password as Field Commander.</p>
      <form onSubmit={onSubmit}>
        <label className="field">
          <span>Email</span>
          <input
            type="email"
            autoComplete="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>
        <label className="field">
          <span>Password</span>
          <input
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </label>
        {error ? <p className="error">{error}</p> : null}
        <button className="primary" type="submit" disabled={busy}>
          {busy ? "Signing in" : "Sign in"}
        </button>
      </form>
    </main>
  );
}

function Court({ onSignOut }: { onSignOut: () => void }) {
  const [teams, setTeams] = useState<Team[]>([]);
  const [teamId, setTeamId] = useState<string>("");
  const [tab, setTab] = useState<Tab>("season");
  const [gameId, setGameId] = useState<string | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    getSupabase()
      .from("score_teams")
      .select("*")
      .order("name")
      .then(({ data, error: loadError }) => {
        if (loadError) {
          setError(loadError.message);
          return;
        }
        const rows = (data ?? []) as Team[];
        setTeams(rows);
        const vienna = rows.find((team) => team.name === "Vienna 6th");
        setTeamId((vienna ?? rows[0])?.id ?? "");
      });
  }, []);

  const team = teams.find((item) => item.id === teamId) ?? null;

  return (
    <>
      <main className="app">
        {error ? <p className="error">{error}</p> : null}
        {!team ? (
          <p className="center-note">No teams yet.</p>
        ) : gameId ? (
          <BoxScore gameId={gameId} onBack={() => setGameId(null)} />
        ) : tab === "season" ? (
          <Season team={team} teams={teams} onTeam={setTeamId} onOpen={setGameId} onSignOut={onSignOut} />
        ) : tab === "roster" ? (
          <Roster team={team} />
        ) : (
          <Score team={team} />
        )}
      </main>
      {gameId ? null : (
        <nav className="nav">
          <button className={tab === "season" ? "on" : ""} onClick={() => setTab("season")}>
            Season
          </button>
          <button className={tab === "roster" ? "on" : ""} onClick={() => setTab("roster")}>
            Roster
          </button>
          <button className={tab === "score" ? "on" : ""} onClick={() => setTab("score")}>
            Score
          </button>
        </nav>
      )}
    </>
  );
}

function Season({
  team,
  teams,
  onTeam,
  onOpen,
  onSignOut,
}: {
  team: Team;
  teams: Team[];
  onTeam: (id: string) => void;
  onOpen: (id: string) => void;
  onSignOut: () => void;
}) {
  const [games, setGames] = useState<Game[]>([]);

  useEffect(() => {
    getSupabase()
      .from("score_games")
      .select("*")
      .eq("team_id", team.id)
      .order("game_date", { ascending: false })
      .then(({ data }) => setGames((data ?? []) as Game[]));
  }, [team.id]);

  const finals = games.filter((game) => game.status === "final");
  const record = seasonRecord(finals);
  const points = finals.reduce((sum, game) => sum + game.team_score, 0);

  return (
    <>
      <p className="eyebrow">{team.name}</p>
      <h1>Season</h1>
      {teams.length > 1 ? (
        <select className="team-select" value={team.id} onChange={(event) => onTeam(event.target.value)}>
          {teams.map((item) => (
            <option key={item.id} value={item.id}>
              {item.name}
            </option>
          ))}
        </select>
      ) : null}
      <p className="record">{recordLabel(record)}</p>
      <p className="record-note">
        {finals.length} games · {points} points
      </p>
      <div className="list">
        {games.map((game) => (
          <button key={game.id} className="game-row" onClick={() => onOpen(game.id)}>
            <span className="game-copy">
              <span className="game-name">
                {game.opponent}
                {game.status === "live" ? <span className="live-pill">LIVE</span> : null}
              </span>
              <span className="game-date">{formatGameDate(game.game_date)}</span>
            </span>
            <span className="game-score">
              {game.team_score}–{game.opponent_score}
            </span>
          </button>
        ))}
      </div>
      <button className="ghost" onClick={onSignOut}>
        Sign out
      </button>
    </>
  );
}

function Roster({ team }: { team: Team }) {
  const [players, setPlayers] = useState<Player[]>([]);
  const [editing, setEditing] = useState<Player | null>(null);
  const [adding, setAdding] = useState(false);

  function load() {
    getSupabase()
      .from("score_players")
      .select("*")
      .eq("team_id", team.id)
      .eq("active", true)
      .order("sort_order")
      .then(({ data }) => setPlayers((data ?? []) as Player[]));
  }

  useEffect(load, [team.id]);

  return (
    <>
      <p className="eyebrow">{team.name}</p>
      <h1>Roster</h1>
      <p className="sub">{players.length} players</p>
      <div className="list" style={{ marginTop: 18 }}>
        {players.map((player) => (
          <button key={player.id} className="player-row" onClick={() => setEditing(player)}>
            <span className="num">{player.number}</span>
            <span className="player-name">{player.name}</span>
          </button>
        ))}
      </div>
      <button className="primary" onClick={() => setAdding(true)}>
        Add player
      </button>
      {adding ? (
        <PlayerSheet
          title="Add player"
          onClose={() => setAdding(false)}
          onSave={async (name, number) => {
            await getSupabase().from("score_players").insert({
              team_id: team.id,
              family_id: team.family_id,
              name,
              number,
              sort_order: players.length,
            });
            setAdding(false);
            load();
          }}
        />
      ) : null}
      {editing ? (
        <PlayerSheet
          title="Edit player"
          name={editing.name}
          number={editing.number ?? ""}
          onClose={() => setEditing(null)}
          onSave={async (name, number) => {
            await getSupabase().from("score_players").update({ name, number }).eq("id", editing.id);
            setEditing(null);
            load();
          }}
        />
      ) : null}
    </>
  );
}

function PlayerSheet({
  title,
  name = "",
  number = "",
  onClose,
  onSave,
}: {
  title: string;
  name?: string;
  number?: string;
  onClose: () => void;
  onSave: (name: string, number: string) => Promise<void>;
}) {
  const [nextName, setNextName] = useState(name);
  const [nextNumber, setNextNumber] = useState(number);
  const [busy, setBusy] = useState(false);

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <form
        className="sheet"
        onClick={(event) => event.stopPropagation()}
        onSubmit={async (event) => {
          event.preventDefault();
          setBusy(true);
          await onSave(nextName.trim(), nextNumber.trim());
          setBusy(false);
        }}
      >
        <h2>{title}</h2>
        <label className="field">
          <span>Name</span>
          <input value={nextName} onChange={(event) => setNextName(event.target.value)} required />
        </label>
        <label className="field">
          <span>Number</span>
          <input value={nextNumber} onChange={(event) => setNextNumber(event.target.value)} inputMode="numeric" />
        </label>
        <button className="primary" type="submit" disabled={busy}>
          Save
        </button>
      </form>
    </div>
  );
}

function BoxScore({ gameId, onBack }: { gameId: string; onBack: () => void }) {
  const [game, setGame] = useState<Game | null>(null);
  const [players, setPlayers] = useState<Player[]>([]);

  useEffect(() => {
    getSupabase()
      .from("score_games")
      .select("*, score_player_stats(*)")
      .eq("id", gameId)
      .single()
      .then(({ data }) => setGame(data as Game));
  }, [gameId]);

  useEffect(() => {
    if (!game) return;
    getSupabase()
      .from("score_players")
      .select("*")
      .eq("team_id", game.team_id)
      .then(({ data }) => setPlayers((data ?? []) as Player[]));
  }, [game]);

  if (!game) {
    return <p className="sub">Loading</p>;
  }

  const byId = new Map(players.map((player) => [player.id, player]));
  const lines = [...(game.score_player_stats ?? [])].sort((a, b) => b.points - a.points || a.player_id.localeCompare(b.player_id));

  return (
    <>
      <button className="back" onClick={onBack}>
        Season
      </button>
      <p className="eyebrow">{formatGameDate(game.game_date)}</p>
      <h1>{game.opponent}</h1>
      <p className="box-scoreline">
        {game.team_score}–{game.opponent_score}
      </p>
      {game.comments ? <p className="comment">{game.comments}</p> : null}
      <div className="list" style={{ marginTop: 16 }}>
        {lines.map((line) => {
          const player = byId.get(line.player_id);
          return (
            <div key={line.id} className="player-row">
              <span className="num">{player?.number}</span>
              <span>
                <span className="player-name">{player?.name ?? "Player"}</span>
                <span className="stat-mini" style={{ display: "block", marginTop: 4 }}>
                  {line.points} PTS · {line.rebounds} REB · {line.assists} AST · {line.steals} STL · {line.blocks} BLK · {line.turnovers} TO
                </span>
              </span>
            </div>
          );
        })}
      </div>
    </>
  );
}

const SMALL_STATS: { key: StatKey; label: string; prompt: string }[] = [
  { key: "reb", label: "REB", prompt: "Rebound" },
  { key: "ast", label: "AST", prompt: "Assist" },
  { key: "stl", label: "STL", prompt: "Steal" },
  { key: "blk", label: "BLK", prompt: "Block" },
  { key: "to", label: "TO", prompt: "Turnover" },
  { key: "foul", label: "FOUL", prompt: "Foul" },
];

function Score({ team }: { team: Team }) {
  const [players, setPlayers] = useState<Player[]>([]);
  const [game, setGame] = useState<Game | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [starting, setStarting] = useState(false);
  const [editingFloor, setEditingFloor] = useState(false);
  const [side, setSide] = useState<"us" | "them">("us");
  const [picker, setPicker] = useState<{ key: StatKey; prompt: string } | null>(null);
  const [freeThrow, setFreeThrow] = useState<{ playerId: string | null } | null>(null);
  const [undo, setUndo] = useState<{ side: "us" | "them"; playerId: string | null; key: StatKey } | null>(null);
  const [ending, setEnding] = useState(false);
  const [error, setError] = useState("");

  function loadPlayers() {
    getSupabase()
      .from("score_players")
      .select("*")
      .eq("team_id", team.id)
      .eq("active", true)
      .order("sort_order")
      .then(({ data }) => setPlayers((data ?? []) as Player[]));
  }

  function loadGame() {
    getSupabase()
      .from("score_games")
      .select("*, score_player_stats(*)")
      .eq("team_id", team.id)
      .eq("status", "live")
      .maybeSingle()
      .then(({ data, error: loadError }) => {
        if (loadError) setError(loadError.message);
        setGame((data ?? null) as Game | null);
        setLoaded(true);
      });
  }

  useEffect(() => {
    loadPlayers();
    loadGame();
  }, [team.id]);

  async function apply(nextSide: "us" | "them", playerId: string | null, key: StatKey, direction: 1 | -1) {
    if (!game) return;
    setError("");
    const { error: rpcError } = await getSupabase().rpc("score_apply_event", {
      p_game_id: game.id,
      p_side: nextSide,
      p_player_id: playerId,
      p_stat: key,
      p_direction: direction,
    });
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    setUndo(direction === 1 ? { side: nextSide, playerId, key } : null);
    loadGame();
  }

  function ask(key: StatKey, prompt: string) {
    if (side === "them") {
      if (key === "ft") setFreeThrow({ playerId: null });
      else if (key === "points2" || key === "points3") void apply("them", null, key, 1);
      return;
    }
    setPicker({ key, prompt });
  }

  if (!loaded) return <p className="sub">Loading</p>;

  if (!game) {
    return (
      <>
        <p className="eyebrow">{team.name}</p>
        <h1>Score</h1>
        <p className="center-note">No game in progress. Start one when you get to the gym.</p>
        <button className="primary" onClick={() => setStarting(true)}>
          Start game
        </button>
        {starting ? (
          <StartSheet
            players={players}
            onClose={() => setStarting(false)}
            onStart={async (opponent, date, floor) => {
              const { data, error: insertError } = await getSupabase()
                .from("score_games")
                .insert({
                  team_id: team.id,
                  family_id: team.family_id,
                  opponent,
                  game_date: date,
                  status: "live",
                  period: 1,
                })
                .select("*")
                .single();
              if (insertError || !data) {
                setError(insertError?.message ?? "Could not start the game");
                return;
              }
              const created = data as Game;
              if (floor.length) {
                await getSupabase().from("score_player_stats").upsert(
                  floor.map((playerId) => ({
                    game_id: created.id,
                    player_id: playerId,
                    family_id: team.family_id,
                    on_court: true,
                  })),
                  { onConflict: "game_id,player_id" },
                );
              }
              setStarting(false);
              loadGame();
            }}
          />
        ) : null}
        {error ? <p className="error">{error}</p> : null}
      </>
    );
  }

  const onCourt = new Set((game.score_player_stats ?? []).filter((line) => line.on_court).map((line) => line.player_id));
  const floor = players.filter((player) => onCourt.has(player.id));
  const them = side === "them";

  return (
    <>
      <p className="eyebrow">{team.name}</p>
      <h1>vs {game.opponent}</h1>
      <section className="scoreboard">
        <div>
          <div className="points">{game.team_score}</div>
          <span className="side-label">US</span>
        </div>
        <button
          className="period"
          onClick={() => {
            const next = game.period >= 5 ? 1 : game.period + 1;
            getSupabase().from("score_games").update({ period: next }).eq("id", game.id).then(loadGame);
          }}
        >
          {periodLabel(game.period)}
        </button>
        <div>
          <div className="points them">{game.opponent_score}</div>
          <span className="side-label">THEM</span>
        </div>
      </section>

      <div className="section-row">
        <p className="section-label">ON THE FLOOR</p>
        <button className="ghost" onClick={() => setEditingFloor(true)}>
          Edit
        </button>
      </div>
      <div className="list">
        {floor.map((player) => (
          <div key={player.id} className="player-row">
            <span className="num">{player.number}</span>
            <span className="player-name">{player.name}</span>
          </div>
        ))}
        {floor.length === 0 ? <p className="sub">Choose who is playing.</p> : null}
      </div>

      <div className="side-switch">
        <button className={side === "us" ? "on" : ""} onClick={() => setSide("us")}>
          Us
        </button>
        <button className={side === "them" ? "on" : ""} onClick={() => setSide("them")}>
          Them
        </button>
      </div>
      <div className="stat-row">
        <button className="stat" onClick={() => ask("points2", "2-pointer")}>+2</button>
        <button className="stat" onClick={() => ask("points3", "3-pointer")}>+3</button>
        <button className="stat outline" onClick={() => ask("ft", "Free throw")}>FT</button>
      </div>
      <div className="small-row">
        {SMALL_STATS.map((stat) => (
          <button key={stat.key} className="small-stat" disabled={them} onClick={() => ask(stat.key, stat.prompt)}>
            {stat.label}
          </button>
        ))}
      </div>
      {undo ? (
        <button
          className="ghost"
          onClick={() => apply(undo.side, undo.playerId, undo.key, -1)}
        >
          Undo last stat
        </button>
      ) : null}
      <button className="ghost danger" onClick={() => setEnding(true)}>
        End game
      </button>
      {ending ? (
        <div className="sheet-backdrop" onClick={() => setEnding(false)}>
          <div className="sheet" onClick={(event) => event.stopPropagation()}>
            <h2>End game</h2>
            <p className="sub">
              {game.team_score}–{game.opponent_score} vs {game.opponent} will be saved to the season.
            </p>
            <button
              className="primary"
              onClick={async () => {
                await getSupabase().from("score_games").update({ status: "final" }).eq("id", game.id);
                setEnding(false);
                setGame(null);
                loadGame();
              }}
            >
              Save and end
            </button>
            <button className="ghost" onClick={() => setEnding(false)}>
              Keep playing
            </button>
          </div>
        </div>
      ) : null}
      {error ? <p className="error">{error}</p> : null}

      {picker ? (
        <div className="sheet-backdrop" onClick={() => setPicker(null)}>
          <div className="sheet" onClick={(event) => event.stopPropagation()}>
            <h2>{picker.prompt}</h2>
            <div className="list">
              {(floor.length ? floor : players).map((player) => (
                <button
                  key={player.id}
                  className="player-row"
                  onClick={() => {
                    if (picker.key === "ft") setFreeThrow({ playerId: player.id });
                    else void apply("us", player.id, picker.key, 1);
                    setPicker(null);
                  }}
                >
                  <span className="num">{player.number}</span>
                  <span className="player-name">{player.name}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {freeThrow ? (
        <div className="sheet-backdrop" onClick={() => setFreeThrow(null)}>
          <div className="sheet" onClick={(event) => event.stopPropagation()}>
            <h2>Free throw</h2>
            <button
              className="primary"
              onClick={() => {
                void apply(freeThrow.playerId ? "us" : "them", freeThrow.playerId, "ft", 1);
                setFreeThrow(null);
              }}
            >
              Made
            </button>
            <button className="ghost" onClick={() => setFreeThrow(null)}>
              Missed
            </button>
          </div>
        </div>
      ) : null}

      {editingFloor ? (
        <FloorSheet
          players={players}
          selected={onCourt}
          onClose={() => setEditingFloor(false)}
          onSave={async (ids) => {
            const rows = players.map((player) => ({
              game_id: game.id,
              player_id: player.id,
              family_id: team.family_id,
              on_court: ids.has(player.id),
            }));
            const { error: upsertError } = await getSupabase()
              .from("score_player_stats")
              .upsert(rows, { onConflict: "game_id,player_id" });
            if (upsertError) setError(upsertError.message);
            setEditingFloor(false);
            loadGame();
          }}
        />
      ) : null}
    </>
  );
}

function StartSheet({
  players,
  onClose,
  onStart,
}: {
  players: Player[];
  onClose: () => void;
  onStart: (opponent: string, date: string, floor: string[]) => Promise<void>;
}) {
  const today = new Date().toISOString().slice(0, 10);
  const [opponent, setOpponent] = useState("");
  const [date, setDate] = useState(today);
  const [floor, setFloor] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  function toggle(id: string) {
    setFloor((current) => {
      if (current.includes(id)) return current.filter((item) => item !== id);
      if (current.length >= 5) return current;
      return [...current, id];
    });
  }

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <form
        className="sheet"
        onClick={(event) => event.stopPropagation()}
        onSubmit={async (event) => {
          event.preventDefault();
          setBusy(true);
          await onStart(opponent.trim(), date, floor);
          setBusy(false);
        }}
      >
        <h2>Start game</h2>
        <label className="field">
          <span>Opponent</span>
          <input value={opponent} onChange={(event) => setOpponent(event.target.value)} required />
        </label>
        <label className="field">
          <span>Date</span>
          <input type="date" value={date} onChange={(event) => setDate(event.target.value)} required />
        </label>
        <p className="section-label">ON THE FLOOR</p>
        <div className="list">
          {players.map((player) => (
            <label key={player.id} className="player-row check-row">
              <input type="checkbox" checked={floor.includes(player.id)} onChange={() => toggle(player.id)} />
              <span className="num">{player.number}</span>
              <span className="player-name">{player.name}</span>
            </label>
          ))}
        </div>
        <button className="primary" type="submit" disabled={busy}>
          Start
        </button>
      </form>
    </div>
  );
}

function FloorSheet({
  players,
  selected,
  onClose,
  onSave,
}: {
  players: Player[];
  selected: Set<string>;
  onClose: () => void;
  onSave: (ids: Set<string>) => Promise<void>;
}) {
  const [ids, setIds] = useState(new Set(selected));

  function toggle(id: string) {
    setIds((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else if (next.size < 5) next.add(id);
      return next;
    });
  }

  return (
    <div className="sheet-backdrop" onClick={onClose}>
      <div className="sheet" onClick={(event) => event.stopPropagation()}>
        <h2>On the floor</h2>
        <div className="list">
          {players.map((player) => (
            <label key={player.id} className="player-row check-row">
              <input type="checkbox" checked={ids.has(player.id)} onChange={() => toggle(player.id)} />
              <span className="num">{player.number}</span>
              <span className="player-name">{player.name}</span>
            </label>
          ))}
        </div>
        <button className="primary" onClick={() => onSave(ids)}>
          Save
        </button>
      </div>
    </div>
  );
}
