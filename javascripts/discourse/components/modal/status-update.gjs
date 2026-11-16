import { Input } from "@ember/component";
import { action } from "@ember/object";
import { themePrefix } from "virtual:theme";
import UserStatusModal from "discourse/components/modal/user-status";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DTimeShortcutPicker from "discourse/ui-kit/d-time-shortcut-picker";
import { i18n } from "discourse-i18n";
import StatusPresetInput from "../status-preset-input";
import StatusSuggestions from "../status-suggestions";

export default class StatusUpdateModal extends UserStatusModal {
  @action
  updateStatus({ emoji, description }) {
    this.status.emoji = emoji;
    this.status.description = description;
  }

  <template>
    <DModal
      @title={{i18n "user_status.set_custom_status"}}
      @closeModal={{@closeModal}}
      class="user-status wiblio-status-update"
    >
      <:body>
        <StatusSuggestions @status={{this.status}} />

        <div class="control-group">
          <h2 class="wiblio-status-update__custom-heading">
            {{i18n (themePrefix "wiblio_status_update.custom")}}
          </h2>
          <StatusPresetInput
            @status={{this.status}}
            @onChange={{this.updateStatus}}
            @autofocus={{true}}
            @context="user-status"
            @placeholder={{i18n "user_status.what_are_you_doing"}}
            @inputClass="user-status-description"
          />
        </div>

        {{#unless @model.hidePauseNotifications}}
          <div class="control-group pause-notifications">
            <label class="checkbox-label">
              <Input @type="checkbox" @checked={{@model.pauseNotifications}} />
              {{i18n "user_status.pause_notifications"}}
            </label>
          </div>
        {{/unless}}

        <div class="control-group control-group-remove-status">
          <label class="control-label">
            {{i18n "user_status.remove_status"}}
          </label>

          {{! template-lint-disable no-capital-arguments }}
          <DTimeShortcutPicker
            @timeShortcuts={{this.timeShortcuts}}
            @hiddenOptions={{this.hiddenTimeShortcutOptions}}
            @customLabels={{this.customTimeShortcutLabels}}
            @prefilledDatetime={{this.prefilledDateTime}}
            @onTimeSelected={{this.onTimeSelected}}
            @_itsatrap={{this._itsatrap}}
          />
          {{! template-lint-enable no-capital-arguments }}
        </div>
      </:body>

      <:footer>
        <DButton
          @label="user_status.save"
          @disabled={{this.saveDisabled}}
          @action={{this.saveAndClose}}
          class="btn-primary"
        />
        <DModalCancel @close={{@closeModal}} />

        {{#if this.showDeleteButton}}
          <DButton
            @icon="trash-can"
            @title={{themePrefix "wiblio_status_update.delete_status"}}
            @action={{this.delete}}
            class="delete-status btn-danger"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
