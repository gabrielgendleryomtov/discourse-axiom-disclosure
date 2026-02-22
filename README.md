# Axiom Disclosure

A Discourse plugin for staff to record safeguarding disclosures with a single click.

This plugin adds a staff-only disclosure button in the post menu and chat message menu. When clicked and confirmed, the plugin:

- Hides the selected content immediately (post or chat message)
- Silences the content author for a configurable duration (optional)
- Exports a JSON record to the server filesystem (outside the database)
- Sends an optional email notification via Discourse's mail pipeline

This is designed for safeguarding workflows where you want an immutable record of an incident even if the user deletes their account.

---

## Behaviour

### Staff post and chat message menu button

When enabled, staff users see a **shield** disclosure action in post menus and chat message menus. Clicking it:

1. Opens a confirmation dialog (“Flag this content as a disclosure?”).
2. On confirmation, performs safeguarding actions server-side.

### Server-side actions (v0.1.0)

- **Hide**
  - For posts: the post is hidden immediately.
  - For chat messages: the chat message is trashed (hidden from chat stream).
- **Silence**
  - The content author is silenced for `axiom_disclosure_silence_duration_hours`.
  - If the value is `0`, no silencing is performed.
- **Export**
  - A JSON record is written to disk, one file per disclosure.
- **Email notification**
  - If `axiom_disclosure_notification_email` is set, the disclosure payload is emailed as JSON (`text/plain`) via Discourse's email pipeline.
  - If blank, no email is sent.
- **Optional redaction**
  - When enabled, after export/notification the plugin replaces post/chat content with redacted text.
  - Original content remains available in revision history for authorized staff.

---

## Export format

Each disclosure produces a single JSON file containing:

- Staff actor details
- User details
- Post details (`post`) or chat message details (`chat_message`) depending on source
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
- **Notify user about hidden content**
  - Disabled by default.
  - When disabled, disclosure hides post content without sending the standard Discourse hidden-post system message/email to the author.
- **Redact disclosed content after reporting**
  - Enabled by default.
  - Runs after JSON export and optional email notification.
- **Redacted content text**
  - Replacement text written into post/chat content when redaction runs.

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
