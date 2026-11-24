"""The [PAUSE] handshake: a numbered prompt with a default (Enter = Done), or a scripted answer.

answers.toml: [answers] keyed by pause title, values done / retry / skip / abort / HUMAN.
HUMAN (or no entry) asks the person; --auto / TXMDM_BDD_AUTO=1 takes the default everywhere.
"""

import os
import tomllib
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

from roadrunner.api import Answer, Handshake

HUMAN = "HUMAN"
OPTIONS = (Answer.DONE, Answer.RETRY, Answer.SKIP, Answer.ABORT)


def auto_from_env() -> bool:
    return os.environ.get("TXMDM_BDD_AUTO", "") in ("1", "true", "yes")


def load_answers(path: Path | None) -> dict[str, str]:
    if path is None or not path.is_file():
        return {}
    table = tomllib.loads(path.read_text(encoding="utf-8")).get("answers", {})
    return {str(k): str(v) for k, v in table.items()}


def parse(text: str) -> Answer | None:
    """'' -> Done; a number 1-4 or the word, any case."""
    word = text.strip().lower()
    if not word:
        return Answer.DONE
    if word.isdigit() and 1 <= int(word) <= len(OPTIONS):
        return OPTIONS[int(word) - 1]
    return next((a for a in OPTIONS if a.value == word), None)


@dataclass
class Pauses:
    auto: bool = False
    answers: dict[str, str] = field(default_factory=dict)
    ask: Callable[[str], str] = input
    say: Callable[[str], None] = print
    log: list[Handshake] = field(default_factory=list)

    def pause(self, title: str, lines: list[str]) -> Handshake:
        scripted = self.answers.get(title, HUMAN)
        if self.auto:
            answer, source = Answer.DONE, "auto"
        elif scripted != HUMAN:
            answer, source = parse(scripted) or Answer.ABORT, "scripted"
        else:
            answer, source = self._ask(title, lines), "human"
        self.say(f"[PAUSE] {title}: {answer.value} ({source})")
        shake = Handshake(title=title, answer=answer, source=source, at=datetime.now(UTC))
        self.log.append(shake)
        return shake

    def _ask(self, title: str, lines: list[str]) -> Answer:
        bar = "-" * 72
        self.say("\n".join([bar, f"[PAUSE] {title}", *[f"  {x}" for x in lines], bar]))
        self.say("  [1] Done (default, press Enter)  [2] Retry  [3] Skip  [4] Abort")
        while True:
            try:
                picked = parse(self.ask("  Your choice: "))
            except EOFError:  # keyboard closed (piped input ran out): stop safely
                return Answer.ABORT
            if picked is not None:
                return picked
            self.say("  Type 1-4 or done / retry / skip / abort.")
