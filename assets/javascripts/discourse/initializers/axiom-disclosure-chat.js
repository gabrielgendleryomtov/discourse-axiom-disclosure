import { debug } from "@ember/debug";
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
const LOG_PREFIX = "[axiom-disclosure] chat initializer:";

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
    debug(`${LOG_PREFIX} already patched, skipping`);
    return;
  }

  debug(`${LOG_PREFIX} patching ChatMessageInteractor`);

  const secondaryActionsDescriptor = Object.getOwnPropertyDescriptor(
    ChatMessageInteractor.prototype,
    "secondaryActions"
  );

  if (!secondaryActionsDescriptor?.get) {
    debug(
      `${LOG_PREFIX} missing descriptors; cannot patch getter=${Boolean(
        secondaryActionsDescriptor?.get
      )}`
    );
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

      debug(
        `${LOG_PREFIX} adding disclosure action messageId=${this?.message?.id} userId=${this?.currentUser?.id}`
      );

      actions.push({
        id: ACTION_ID,
        name: i18n("axiom_disclosure.flag_title"),
        icon: "shield-halved",
      });

      return actions;
    },
  });

  if (!ChatMessageInteractor.prototype[ACTION_ID]) {
    Object.defineProperty(ChatMessageInteractor.prototype, ACTION_ID, {
      configurable: true,
      enumerable: false,
      writable: true,
      value: async function () {
        debug(
          `${LOG_PREFIX} disclosure action clicked messageId=${this?.message?.id} channelId=${this?.message?.channel?.id}`
        );

        const response = await this.modal.show(AxiomDisclosureModal, {
          confirmMessageKey: "axiom_disclosure.confirm_message_chat",
        });

        debug(`${LOG_PREFIX} modal response confirmed=${response?.confirmed}`);

        if (!response?.confirmed) {
          return;
        }

        const observation = response.observation || "";

        try {
          const result = await ajax("/axiom-disclosure/flag", {
            type: "POST",
            data: { chat_message_id: this.message.id, observation },
          });

          debug(
            `${LOG_PREFIX} disclosure request success messageId=${this?.message?.id}`
          );

          const dialog = getOwner(this).lookup("service:dialog");
          dialog.alert({
            title: i18n("axiom_disclosure.success_title"),
            message: buildSuccessMessageHtml(result),
          });
        } catch (e) {
          debug(`${LOG_PREFIX} disclosure request failed`, e);
          popupAjaxError(e);
        }
      },
    });

    debug(`${LOG_PREFIX} action method added`);
  }

  patched = true;
  debug(`${LOG_PREFIX} patch complete`);
}

export default {
  name: "axiom-disclosure-chat",

  initialize() {
    debug(`${LOG_PREFIX} initialize start`);
    withPluginApi(() => {
      try {
        patchChatMessageInteractor();
      } catch (e) {
        debug(`${LOG_PREFIX} fatal error while patching`, e);
        throw e;
      }
    });
    debug(`${LOG_PREFIX} initialize end`);
  },
};
