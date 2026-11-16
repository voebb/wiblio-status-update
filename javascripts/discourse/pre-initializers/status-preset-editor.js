import { settings, themePrefix } from "virtual:theme";
import { withPluginApi } from "discourse/lib/plugin-api";
import { getObjectForTheme } from "discourse/lib/theme-settings-store";
import { i18n } from "discourse-i18n";
import StatusHistorySetting from "../components/status-history-setting";
import StatusPresetEditor from "../components/status-preset-editor";

export default {
  name: "wiblio-status-preset-editor",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      api.modifyClass(
        "component:theme-setting-editor",
        (Superclass) =>
          class extends Superclass {
            get isWiblioStatusSetting() {
              return (
                getObjectForTheme(Number(this.args.model?.id)) === settings
              );
            }

            get isWiblioStatusPresets() {
              return (
                this.setting.setting === "status_presets" &&
                this.isWiblioStatusSetting
              );
            }

            get isWiblioStatusHistory() {
              return (
                this.setting.setting === "show_frequent_statuses" &&
                this.isWiblioStatusSetting
              );
            }

            get typeClass() {
              return this.isWiblioStatusPresets
                ? "wiblio-status-presets"
                : super.typeClass;
            }

            get displayDescription() {
              return this.isWiblioStatusHistory || super.displayDescription;
            }

            get settingName() {
              return this.isWiblioStatusPresets
                ? i18n(themePrefix("wiblio_status_update.editor.title"))
                : super.settingName;
            }

            get settingEditButton() {
              return this.isWiblioStatusPresets
                ? null
                : super.settingEditButton;
            }

            get resolvedComponent() {
              if (this.isWiblioStatusHistory) {
                return StatusHistorySetting;
              }

              return this.isWiblioStatusPresets
                ? StatusPresetEditor
                : super.resolvedComponent;
            }
          },
        { ignoreMissing: true }
      );
    });
  },
};
