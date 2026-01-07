import { withPluginApi } from "discourse/lib/plugin-api";
import AxiomDisclosureButton from "../components/axiom-disclosure-button";

export default {
  name: "axiom-disclosure",

  initialize() {
    withPluginApi("1.34.0", (api) => {
      if (!Discourse.SiteSettings.axiom_disclosure_enabled) return;

      const currentUser = api.getCurrentUser();
      if (!currentUser || !currentUser.staff) return;

      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { post, firstButtonKey } }) => {
          dag.add("axiom-disclosure", AxiomDisclosureButton, {
            after: firstButtonKey,
            props: { post },
          });
        }
      );
    });
  },
};
