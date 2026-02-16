# Axiom Disclosure

A Discourse plugin for staff to record safeguarding disclosures with a single click.

This plugin adds a staff-only disclosure button in the post menu and chat message menu. When clicked and confirmed, the plugin:

- Hides the post immediately
- Silences the post author for a configurable duration (optional)
- Exports a JSON record to the server filesystem (outside the database)
- Triggers an external notification hook (stubbed in v0.1.0)

This is designed for safeguarding workflows where you want an immutable record of an incident even if the user deletes their account.

---

## Behaviour

### Staff post and chat message menu button

When enabled, staff users see a **shield** disclosure action in post menus and chat message menus. Clicking it:

1. Opens a confirmation dialog (“Flag this post as a disclosure?”).
2. On confirmation, performs safeguarding actions server-side.

### Server-side actions (v0.1.0)

- **Flag + hide**
  - A staff flag is created (for audit trail / moderation UI).
  - The post is explicitly hidden immediately.
- **Silence**
  - The post author is silenced for `axiom_disclosure_silence_duration_hours`.
  - If the value is `0`, no silencing is performed.
  - Note: if a user is already silenced, v0.1.0 does not extend the silence duration (planned improvement).
- **Export**
  - A JSON record is written to disk, one file per disclosure.
- **External notification**
  - If `axiom_disclosure_notification_email` is set, the disclosure payload is emailed as JSON (`text/plain`) via Discourse's email pipeline.
  - If blank, no email is sent.

---

## Export format

Each disclosure produces a single JSON file containing:

- Staff actor details
- User details
- Post raw + cooked text
- Topic metadata
- Timestamps

The JSON is written outside the database so the record remains available even if the user deletes content or their account.

---

## Export location

### Default behaviour

The plugin setting `axiom_disclosure_export_dir` may be left blank. In that case, the plugin uses a fallback directory:

- `Rails.root/tmp/axiom-disclosures`

This works well for development and local testing.

### Recommended production configuration

For production, you should set `axiom_disclosure_export_dir` to a **persistent mounted directory** that is writable by the Discourse container user (often `discourse`). For example:

- `/shared/axiom-disclosures`

> Note: In some dev environments `/shared` may not be writable by default. In production the server admin should create and grant appropriate permissions to the export directory.

---

## Settings

Admin → Settings → Plugins → Axiom Disclosure

- **Enable Axiom disclosure flagging button**
- **Silence duration (hours)**  
  - `0` disables silencing
- **Export directory**
  - Leave blank to use fallback (`Rails.root/tmp/axiom-disclosures`)
- **Silencing reason**
  - Generic text stored in staff-facing logs (should not contain sensitive details)
- **Notification recipient email**
  - Leave blank to disable disclosure report emails

---

## Storage and security

- Exported disclosure files are written to the **server filesystem** and are **not served over HTTP** by Discourse.
- They are accessible only to administrators / staff with server access.
- Because exports are stored outside the database, they remain available even if posts are edited or deleted.

⚠️ Safeguarding data is sensitive. Ensure the export directory:
- is not publicly accessible,
- is included in appropriate backup/security procedures,
- follows your organisation’s data retention policy.

---

## Development notes

### Running in dev
This plugin is compatible with Discourse **Glimmer post menu mode** and uses the Discourse **dialog service** (not Bootbox).

If you change plugin settings in `config/settings.yml`, you must fully restart the dev environment:

```bash
d/shutdown_dev && d/boot_dev
