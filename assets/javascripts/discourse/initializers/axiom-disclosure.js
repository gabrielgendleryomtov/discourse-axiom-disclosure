import { debug } from "@ember/debug";
import { withPluginApi } from "discourse/lib/plugin-api";
import AxiomDisclosureButton from "../components/axiom-disclosure-button";

export default {
  name: "axiom-disclosure",

  initialize() {
    debug("[axiom-disclosure] post-menu initializer: start");

    withPluginApi((api) => {
      try {
        const siteSettings = api.container.lookup("service:site-settings");
        const enabled = siteSettings?.axiom_disclosure_enabled;
        debug(
          `[axiom-disclosure] post-menu initializer: site setting enabled=${enabled}`
        );

        if (!enabled) {
          debug(
            "[axiom-disclosure] post-menu initializer: skipping (plugin disabled)"
          );
          return;
        }

        const currentUser = api.getCurrentUser();
        debug(
          `[axiom-disclosure] post-menu initializer: current user id=${currentUser?.id} staff=${currentUser?.staff}`
        );

        if (!currentUser || !currentUser.staff) {
          debug(
            "[axiom-disclosure] post-menu initializer: skipping (not staff)"
          );
          return;
        }

        api.registerValueTransformer(
          "post-menu-buttons",
          ({ value: dag, context: { post, firstButtonKey } }) => {
            dag.add("axiom-disclosure", AxiomDisclosureButton, {
              after: firstButtonKey,
              props: { post },
            });
          }
        );

        debug(
          "[axiom-disclosure] post-menu initializer: transformer registered"
        );
      } catch (e) {
        debug(
          "[axiom-disclosure] post-menu initializer: error during setup",
          e
        );
        throw e;
      }
    });

    debug("[axiom-disclosure] post-menu initializer: end");
  },
};
