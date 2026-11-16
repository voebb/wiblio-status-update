import { getOwner } from "@ember/owner";
import UserStatusModal from "discourse/components/modal/user-status";
import { withPluginApi } from "discourse/lib/plugin-api";
import StatusUpdateModal from "../components/modal/status-update";

export default {
  name: "wiblio-status-update",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "service:modal",
        (Superclass) =>
          class extends Superclass {
            show(modal, options) {
              if (modal !== UserStatusModal) {
                return super.show(...arguments);
              }

              const history = getOwner(this).lookup(
                "service:wiblio-status-history"
              );
              const model = options.model;

              return super.show(StatusUpdateModal, {
                ...options,
                model: {
                  ...model,
                  saveAction: async (status, ...args) => {
                    const result = await model.saveAction(status, ...args);
                    if (model.hidePauseNotifications) {
                      // Account preferences persist only when the page is saved.
                      history.stage(status);
                    } else {
                      history.record(status);
                    }
                    return result;
                  },
                  deleteAction: async (...args) => {
                    const result = await model.deleteAction(...args);
                    history.clearPending();
                    return result;
                  },
                },
              });
            }
          }
      );

      api.modifyClass(
        "model:user",
        (Superclass) =>
          class extends Superclass {
            async save(fields) {
              const status = { ...this.status };
              const result = await super.save(...arguments);
              if (!fields || fields.includes("status")) {
                getOwner(this)
                  .lookup("service:wiblio-status-history")
                  .commitPending(this.id, status);
              }
              return result;
            }
          }
      );
    });
  },
};
