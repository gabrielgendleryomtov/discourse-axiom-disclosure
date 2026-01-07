import Component from "@glimmer/component";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import I18n from "I18n";
import { on } from "@ember/modifier";

export default class AxiomDisclosureModal extends Component {
  @tracked observation = "";

  get title() {
    return I18n.t("axiom_disclosure.confirm_title");
  }

  get intro() {
    return I18n.t("axiom_disclosure.confirm_message");
  }

  get label() {
    return I18n.t("axiom_disclosure.observation_label");
  }

  get placeholder() {
    return I18n.t("axiom_disclosure.observation_placeholder");
  }

  @action updateObservation(event) {
    this.observation = event.target.value;
  }

  @action confirm() {
    // closeModal is provided by DModal
    this.args.closeModal?.({ confirmed: true, observation: this.observation.trim() });
  }

  @action cancel() {
    this.args.closeModal?.({ confirmed: false });
  }

  <template>
    <DModal @title={{this.title}} @closeModal={{this.cancel}}>
      <div class="axiom-disclosure-modal">
        <p>{{this.intro}}</p>

        <p><strong>{{this.label}}</strong></p>
        <textarea
          value={{this.observation}}
          placeholder={{this.placeholder}}
          {{on "input" this.updateObservation}}
          style="width: 100%; min-height: 120px; resize: vertical;"
        ></textarea>

        <div class="axiom-disclosure-modal__buttons" style="margin-top: 1em; display: flex; gap: 0.5em;">
          <DButton @action={{this.confirm}} @label="axiom_disclosure.confirm_button" class="btn-primary" />
          <DButton @action={{this.cancel}} @label="axiom_disclosure.cancel_button" />
        </div>
      </div>
    </DModal>
  </template>
}
