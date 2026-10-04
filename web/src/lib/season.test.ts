import { describe, expect, it } from "vitest";
import { periodLabel, recordLabel, seasonRecord } from "./season";

describe("seasonRecord", () => {
  it("counts the Vienna 6th season", () => {
    const record = seasonRecord([
      { team_score: 37, opponent_score: 26 },
      { team_score: 41, opponent_score: 46 },
      { team_score: 54, opponent_score: 49 },
      { team_score: 68, opponent_score: 40 },
      { team_score: 31, opponent_score: 31 },
      { team_score: 45, opponent_score: 41 },
      { team_score: 50, opponent_score: 37 },
      { team_score: 25, opponent_score: 43 },
    ]);
    expect(record).toEqual({ wins: 5, losses: 2, ties: 1 });
    expect(recordLabel(record)).toBe("5–2–1");
  });
});

describe("periodLabel", () => {
  it("labels quarters and overtime", () => {
    expect(periodLabel(3)).toBe("Q3");
    expect(periodLabel(5)).toBe("OT");
  });
});
