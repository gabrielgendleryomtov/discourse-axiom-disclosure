import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

function escapeHtml(str) {
  return (str || "").replace(/[&<>"']/g, (c) => {
    switch (c) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      case "'": return "&#039;";
      default: return c;
    }
  });
}

function buildSuccessMessageHtml(result) {
  const items = [];

  items.push(
    result.hidden
      ? I18n.t("axiom_disclosure.action_post_hidden")
      : I18n.t("axiom_disclosure.action_post_already_hidden")
  );

  items.push(
    result.silenced
      ? I18n.t("axiom_disclosure.action_user_silenced")
      : I18n.t("axiom_disclosure.action_user_not_silenced")
  );

  if (result.export_path) {
    const filename = result.export_path.split("/").pop();
    items.push(I18n.t("axiom_disclosure.action_export_saved", { filename }));
  } else {
    items.push(I18n.t("axiom_disclosure.action_export_not_saved"));
  }

  items.push(
    result.notified
      ? I18n.t("axiom_disclosure.action_notified")
      : I18n.t("axiom_disclosure.action_not_notified")
  );

  const intro = escapeHtml(I18n.t("axiom_disclosure.success_message_intro"));

  const html = `
    <p>${intro}</p>
    <ul>
      ${items.map((i) => `<li>${escapeHtml(i)}</li>`).join("")}
    </ul>
  `;

  return htmlSafe(html);
}

export default class AxiomDisclosureButton extends Component {
  @service dialog;

  @action
  async flagDisclosure() {
    const post = this.args?.post;
    if (!post?.id) return;

    const confirmMessage = I18n.t("axiom_disclosure.confirm_message");
    const confirmed = await this.dialog.confirm({ message: confirmMessage });
    if (!confirmed) return;

    try {
      const result = await ajax("/axiom-disclosure/flag", {
        type: "POST",
        data: { post_id: post.id },
      });

      const html = buildSuccessMessageHtml(result);
      this.dialog.alert({
        title: I18n.t("axiom_disclosure.success_title"),
        message: html,
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DButton
      class="axiom-disclosure-flag"
      ...attributes
      @action={{this.flagDisclosure}}
      @icon="shield-halved"
      @title="axiom_disclosure.flag_title"
    />
  </template>
}
