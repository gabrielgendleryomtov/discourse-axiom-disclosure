# Axiom Disclosure

A Discourse plugin for staff to flag safeguarding disclosures with a single click.

## Behaviour

A staff-only post menu button ("Disclosure") allows a coach/mentor to:

- Hide the post
- Silence the user temporarily (configurable duration)
- Export disclosure details to a persistent file outside the database
- Notify an external channel (stubbed in v0.1.0)

## Export

Disclosures are appended to JSONL files stored in:

`/shared/disclosures/disclosures_YYYY-MM-DD.jsonl`

This location is persistent in Docker-based Discourse installs.

## External notification

In v0.1.0 external notification is a stub method (`notify_external`) which logs a TODO.
Future versions may send email or webhook notifications.

## Settings

Admin → Settings → Plugins → Axiom Disclosure

- Enable Axiom disclosure flagging
- Silence duration (hours)
- Export path

## Storage and security

Disclosure records are written to the server filesystem under:

`/shared/private/axiom-disclosures`

This location is a persistent Docker volume and is **not served over HTTP** by Discourse.
Files written here are accessible only to server administrators / staff with shell access, and remain available even if a user deletes their account.