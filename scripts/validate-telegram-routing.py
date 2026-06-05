#!/usr/bin/env python3
"""Validate the GrahmOS Telegram admin routing manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("config/telegram-admin-routing.json")
    if not config_path.exists():
        print(f"error: config file not found: {config_path}", file=sys.stderr)
        return 1

    data = json.loads(config_path.read_text())
    errors: list[str] = []

    if data.get("version") != 1:
        errors.append("version must equal 1")

    route_groups = data.get("routeGroups", {})
    if not isinstance(route_groups, dict) or not route_groups:
        errors.append("routeGroups must be a non-empty object")

    agents = data.get("agents", [])
    if len(agents) != 15:
        errors.append(f"expected 15 agent seats, found {len(agents)}")

    seen_slots: set[str] = set()
    confirmed_agents = 0
    reserved_agents = 0
    for agent in agents:
        slot = agent.get("slot")
        if not slot:
            errors.append("every agent entry needs a slot")
            continue
        if slot in seen_slots:
            errors.append(f"duplicate slot: {slot}")
        seen_slots.add(slot)

        route_group = agent.get("routeGroup")
        if route_group not in route_groups:
            errors.append(f"{slot}: unknown routeGroup {route_group!r}")

        fallback = agent.get("fallbackEscalation")
        if not isinstance(fallback, list) or not fallback:
            errors.append(f"{slot}: fallbackEscalation must be a non-empty list")

        thread_alias = agent.get("threadAlias")
        if not isinstance(thread_alias, str) or not thread_alias:
            errors.append(f"{slot}: threadAlias must be a non-empty string")

        activation_state = agent.get("activationState")
        if activation_state == "pending_roster_confirmation":
            reserved_agents += 1
            continue

        if not agent.get("agentName"):
            errors.append(f"{slot}: non-reserved seats must include agentName")
        if not agent.get("role"):
            errors.append(f"{slot}: non-reserved seats must include role")
        confirmed_agents += 1

    for group_name, group in route_groups.items():
        if not isinstance(group, dict):
            errors.append(f"route group {group_name!r} must be an object")
            continue
        for key in ("chatId", "threadId", "fallbackOwner"):
            if key not in group:
                errors.append(f"route group {group_name!r} missing {key}")

    if errors:
        print("telegram routing validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("telegram routing validation passed")
    print(f"- route groups: {len(route_groups)}")
    print(f"- confirmed or observed seats: {confirmed_agents}")
    print(f"- reserved seats awaiting board confirmation: {reserved_agents}")
    print(f"- activation status: {data.get('activationStatus')}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
