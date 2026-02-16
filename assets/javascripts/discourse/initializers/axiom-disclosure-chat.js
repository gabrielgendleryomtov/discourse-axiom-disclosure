import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import ChatMessageInteractor from "discourse/plugins/chat/discourse/lib/chat-message-interactor";
import AxiomDisclosureModal from "../components/axiom-disclosure-modal";
import { buildSuccessMessageHtml } from "../lib/axiom-disclosure-ui";

const ACTION_ID = "axiomDisclosure";
let patched = false;

function disclosureEnabledForInteractor(interactor) {
  return (
    interactor?.siteSettings?.axiom_disclosure_enabled &&
    interactor?.currentUser?.staff &&
    interactor?.currentUser?.id !== interactor?.message?.user?.id &&
    interactor?.message &&
    !interactor.message.deletedAt
  );
}

function patchChatMessageInteractor() {
  if (patched) {
    return;
  }

  const secondaryActionsDescriptor = Object.getOwnPropertyDescriptor(
    ChatMessageInteractor.prototype,
    "secondaryActions"
  );
  const originalHandleSecondaryActions =
    ChatMessageInteractor.prototype.handleSecondaryActions;

  if (!secondaryActionsDescriptor?.get || !originalHandleSecondaryActions) {
    return;
  }

  Object.defineProperty(ChatMessageInteractor.prototype, "secondaryActions", {
    configurable: true,
    enumerable: false,
    get() {
      const actions = secondaryActionsDescriptor.get.call(this);

      if (!disclosureEnabledForInteractor(this)) {
        return actions;
      }

      actions.push({
        id: ACTION_ID,
        name: i18n("axiom_disclosure.flag_title"),
        icon: "shield-halved",
      });

      return actions;
    },
  });

  ChatMessageInteractor.prototype.handleSecondaryActions = async function (id) {
    if (id === ACTION_ID) {
      const response = await this.modal.show(AxiomDisclosureModal, {
        confirmMessageKey: "axiom_disclosure.confirm_message_chat",
      });
      if (!response?.confirmed) {
        return;
      }

      const observation = response.observation || "";

      try {
        const result = await ajax("/axiom-disclosure/flag", {
          type: "POST",
          data: { chat_message_id: this.message.id, observation },
        });
        const dialog = getOwner(this).lookup("service:dialog");
        dialog.alert({
          title: i18n("axiom_disclosure.success_title"),
          message: buildSuccessMessageHtml(result),
        });
      } catch (e) {
        popupAjaxError(e);
      }

      return;
    }

    return originalHandleSecondaryActions.call(this, id);
  };

  patched = true;
}

export default {
  name: "axiom-disclosure-chat",
  after: "chat-plugin-api",

  initialize() {
    withPluginApi(() => {
      patchChatMessageInteractor();
    });
  },
};
