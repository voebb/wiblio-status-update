import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { themePrefix } from "virtual:theme";
import { i18n } from "discourse-i18n";

export default class StatusHistorySetting extends Component {
  get enabled() {
    return this.args.value === true || this.args.value === "true";
  }

  @action
  toggle(event) {
    this.args.changeValueCallback(String(event.target.checked));
  }

  <template>
    <label class="checkbox-label wiblio-status-history-setting" ...attributes>
      <input
        {{on "input" this.toggle}}
        type="checkbox"
        checked={{this.enabled}}
        disabled={{@disabled}}
      />
      <span>{{i18n
          (themePrefix "wiblio_status_update.remember_history")
        }}</span>
    </label>
  </template>
}
