# Project Operating Model

## Canonical Source of Truth

**GitHub is the Source of Truth.**

All canonical project state, documentation, configuration, and decisions
must be represented in the GitHub repository.

## Applied State

**Server is the Applied State.**

The server reflects the state applied from GitHub but is never a source
of canonical truth.

## Forbidden Actions

Direct edits on the server are **forbidden**.

Any manual change performed directly on the server without going through
the Git-centric change cycle is considered invalid and must be reverted.

## Mandatory Change Cycle

All changes MUST follow this exact sequence:

**GitHub → Codex → Server → GitHub**

Deviation from this cycle is not allowed.

## Roles and Responsibilities

**PM / Control Tower**
- Defines intent and validates correctness

**Execution / Codex**
- Translates intent into concrete changes

**Server / Apply**
- Applies changes exactly as defined
- Reports resulting state back to GitHub
