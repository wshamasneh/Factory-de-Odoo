"""Click command group for orchestrator commands."""
from __future__ import annotations

import click


@click.group("orch")
def orch_group() -> None:
    """Orchestrator: state, phase, and project management."""
