import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { buildSuccessMessageHtml } from "../lib/axiom-disclosure-ui";
import AxiomDisclosureModal from "./axiom-disclosure-modal";

export default class AxiomDisclosureButton extends Component {
  @service dialog;
  @service modal;

  @action
  async flagDisclosure() {
    const post = this.args?.post;
    if (!post?.id) {
      return;
    }

    const response = await this.modal.show(AxiomDisclosureModal);
    if (!response?.confirmed) {
      return;
    }

    const observation = response.observation || "";

    try {
      const result = await ajax("/axiom-disclosure/flag", {
        type: "POST",
        data: { post_id: post.id, observation },
      });

      const html = buildSuccessMessageHtml(result);
      this.dialog.alert({
        title: i18n("axiom_disclosure.success_title"),
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
