import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

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

      this.dialog.alert(JSON.stringify(result));
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
