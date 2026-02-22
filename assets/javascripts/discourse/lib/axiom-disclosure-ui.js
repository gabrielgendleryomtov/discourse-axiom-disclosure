import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

function escapeHtml(str) {
  return (str || "").replace(/[&<>"']/g, (c) => {
    switch (c) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      case "'":
        return "&#039;";
      default:
        return c;
    }
  });
}

export function buildSuccessMessageHtml(result) {
  const items = [];

  items.push(
    result.hidden
      ? i18n("axiom_disclosure.action_post_hidden")
      : i18n("axiom_disclosure.action_post_already_hidden")
  );

  items.push(
    result.silenced
      ? i18n("axiom_disclosure.action_user_silenced")
      : i18n("axiom_disclosure.action_user_not_silenced")
  );

  if (result.export_path) {
    const filename = result.export_path.split("/").pop();
    items.push(i18n("axiom_disclosure.action_export_saved", { filename }));
  } else {
    items.push(i18n("axiom_disclosure.action_export_not_saved"));
  }

  items.push(
    result.notified
      ? i18n("axiom_disclosure.action_notified")
      : i18n("axiom_disclosure.action_not_notified")
  );

  items.push(
    result.redacted
      ? i18n("axiom_disclosure.action_redacted")
      : i18n("axiom_disclosure.action_not_redacted")
  );

  const intro = escapeHtml(i18n("axiom_disclosure.success_message_intro"));

  const html = `
    <p>${intro}</p>
    <ul>
      ${items.map((i) => `<li>${escapeHtml(i)}</li>`).join("")}
    </ul>
  `;

  return htmlSafe(html);
}
