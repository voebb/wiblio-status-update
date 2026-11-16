import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { settings, themePrefix } from "virtual:theme";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";
import { normalizeStatus, sameStatus, statusKey } from "../lib/status-pair";

export default class StatusSuggestions extends Component {
  @service wiblioStatusHistory;

  @tracked history = this.wiblioStatusHistory.entries;

  get presets() {
    const seen = new Set();
    return settings.status_presets.flatMap((preset) => {
      const status = normalizeStatus({
        emoji: preset.emoji,
        description: preset.label,
      });
      if (!status || seen.has(statusKey(status))) {
        return [];
      }
      seen.add(statusKey(status));
      return [status];
    });
  }

  get sections() {
    const sections = [];
    const presets = this.presets;
    if (presets.length) {
      sections.push({
        id: "presets",
        title: i18n(themePrefix("wiblio_status_update.presets")),
        statuses: presets,
      });
    }

    if (settings.show_frequent_statuses) {
      const presetKeys = new Set(presets.map(statusKey));
      const frequent = this.history
        .filter((status) => !presetKeys.has(statusKey(status)))
        .slice(0, settings.frequent_status_limit);

      if (frequent.length) {
        sections.push({
          id: "frequent",
          title: i18n(themePrefix("wiblio_status_update.frequent")),
          statuses: frequent,
        });
      }
    }

    const lastSection = sections.at(-1);
    if (lastSection) {
      lastSection.canClearHistory = this.canClearHistory;
    }

    return sections;
  }

  get canClearHistory() {
    return settings.show_frequent_statuses && this.history.length > 0;
  }

  @action
  selectStatus(status) {
    this.args.status.emoji = status.emoji;
    this.args.status.description = status.description;
  }

  @action
  clearHistory() {
    this.wiblioStatusHistory.clear();
    this.history = [];
  }

  <template>
    <div class="wiblio-status-suggestions" ...attributes>
      {{#each this.sections key="id" as |group|}}
        <section
          class="wiblio-status-suggestions__section"
          aria-label={{group.title}}
          data-status-section={{group.id}}
        >
          <div class="wiblio-status-suggestions__header">
            <h2 class="wiblio-status-suggestions__heading">{{group.title}}</h2>
            {{#if group.canClearHistory}}
              <DButton
                @display="link"
                @label={{themePrefix "wiblio_status_update.clear_history"}}
                @action={{this.clearHistory}}
                class="wiblio-status-suggestions__clear"
              />
            {{/if}}
          </div>
          <div class="wiblio-status-suggestions__choices">
            {{#each group.statuses as |status|}}
              <button
                {{on "click" (fn this.selectStatus status)}}
                type="button"
                aria-pressed={{if (sameStatus status @status) "true" "false"}}
                class={{dConcatClass
                  "btn btn-default wiblio-status-suggestions__button"
                  (if (sameStatus status @status) "is-selected")
                }}
                data-status-emoji={{status.emoji}}
              >
                <span aria-hidden="true">{{dEmoji status.emoji}}</span>
                <span class="wiblio-status-suggestions__label">
                  {{status.description}}
                </span>
              </button>
            {{/each}}
          </div>
        </section>
      {{/each}}
    </div>
  </template>
}
