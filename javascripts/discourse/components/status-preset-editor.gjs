import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { themePrefix } from "virtual:theme";
import Form from "discourse/components/form";
import { eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { normalizeStatus, sameStatus } from "../lib/status-pair";
import StatusPresetInput from "./status-preset-input";

export default class StatusPresetEditor extends Component {
  @service a11y;

  @tracked formData = { status: { emoji: "", description: "" } };
  @tracked editingPreset = null;
  @tracked draggedPreset = null;
  @tracked dropTarget = null;
  @tracked dropAfter = false;

  get presets() {
    return this.args.value || [];
  }

  get editingIndex() {
    return this.presets.indexOf(this.editingPreset);
  }

  get isEditing() {
    return this.editingIndex !== -1;
  }

  get firstSelected() {
    return this.editingIndex <= 0;
  }

  get lastSelected() {
    return this.editingIndex === this.presets.length - 1;
  }

  @action
  validateStatus(name, value, { addError }) {
    const status = normalizeStatus(value);
    let message;
    if (!status) {
      message = i18n(themePrefix("wiblio_status_update.editor.invalid"));
    } else if (
      this.presets.some(
        (preset) =>
          preset !== this.editingPreset &&
          sameStatus(status, {
            emoji: preset.emoji,
            description: preset.label,
          })
      )
    ) {
      message = i18n(themePrefix("wiblio_status_update.editor.duplicate"));
    }

    if (message) {
      addError(name, {
        title: i18n(themePrefix("wiblio_status_update.editor.status_text")),
        message,
      });
    }
  }

  @action
  confirmPreset({ status }) {
    if (this.args.disabled) {
      return;
    }
    const pair = normalizeStatus(status);
    if (!pair) {
      return;
    }

    const presets = [...this.presets];
    const preset = { emoji: pair.emoji, label: pair.description };
    if (this.isEditing) {
      presets.splice(this.editingIndex, 1, preset);
    } else {
      presets.push(preset);
    }
    this.args.changeValueCallback(presets);
    this.cancelEdit();
  }

  @action
  editPreset(preset) {
    this.editingPreset = preset;
    this.formData = {
      status: { emoji: preset.emoji, description: preset.label },
    };
  }

  @action
  cancelEdit() {
    this.editingPreset = null;
    this.formData = { status: { emoji: "", description: "" } };
  }

  @action
  removePreset(preset) {
    if (this.args.disabled) {
      return;
    }
    this.args.changeValueCallback(
      this.presets.filter((item) => item !== preset)
    );
    if (this.editingPreset === preset) {
      this.cancelEdit();
    }
  }

  movePreset(preset, targetIndex) {
    const presets = [...this.presets];
    const fromIndex = presets.indexOf(preset);
    if (
      this.args.disabled ||
      fromIndex < 0 ||
      targetIndex < 0 ||
      targetIndex >= presets.length ||
      fromIndex === targetIndex
    ) {
      return;
    }

    presets.splice(fromIndex, 1);
    presets.splice(targetIndex, 0, preset);
    this.args.changeValueCallback(presets);
    this.a11y.announce(
      i18n(themePrefix("wiblio_status_update.editor.moved"), {
        label: preset.label,
        position: targetIndex + 1,
        count: presets.length,
      })
    );
  }

  @action
  moveSelected(offset) {
    this.movePreset(this.editingPreset, this.editingIndex + offset);
  }

  @action
  dragStart(preset, event) {
    if (this.args.disabled) {
      event.preventDefault();
      return;
    }
    this.draggedPreset = preset;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", preset.label);
  }

  @action
  dragOver(preset, event) {
    if (!this.draggedPreset || this.args.disabled) {
      return;
    }
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
    this.dropTarget = preset;
    const element = event.currentTarget;
    const bounds = element.getBoundingClientRect();
    const pastMiddle = event.clientX > bounds.left + bounds.width / 2;
    this.dropAfter =
      getComputedStyle(element).direction === "rtl" ? !pastMiddle : pastMiddle;
  }

  @action
  dropPreset(preset, event) {
    if (!this.draggedPreset) {
      return;
    }
    event.preventDefault();
    const fromIndex = this.presets.indexOf(this.draggedPreset);
    let targetIndex = this.presets.indexOf(preset) + (this.dropAfter ? 1 : 0);
    if (fromIndex < targetIndex) {
      targetIndex--;
    }
    this.movePreset(this.draggedPreset, targetIndex);
    this.dragEnd();
  }

  @action
  dragEnd() {
    this.draggedPreset = null;
    this.dropTarget = null;
  }

  <template>
    <div class="wiblio-status-preset-editor" ...attributes>
      {{#if this.presets.length}}
        <ul
          class="wiblio-status-preset-editor__list"
          aria-label={{i18n (themePrefix "wiblio_status_update.editor.title")}}
        >
          {{#each this.presets key="@identity" as |preset|}}
            <li
              {{on "dragstart" (fn this.dragStart preset)}}
              {{on "dragover" (fn this.dragOver preset)}}
              {{on "drop" (fn this.dropPreset preset)}}
              {{on "dragend" this.dragEnd}}
              draggable={{if @disabled "false" "true"}}
              class={{dConcatClass
                "wiblio-status-preset-editor__item"
                (if (eq this.editingPreset preset) "is-selected")
                (if (eq this.draggedPreset preset) "is-dragging")
                (if
                  (eq this.dropTarget preset)
                  (if this.dropAfter "is-drop-after" "is-drop-before")
                )
              }}
            >
              <button
                {{on "click" (fn this.editPreset preset)}}
                type="button"
                class="wiblio-status-preset-editor__preset"
                disabled={{@disabled}}
                aria-pressed={{if
                  (eq this.editingPreset preset)
                  "true"
                  "false"
                }}
                title={{i18n (themePrefix "wiblio_status_update.editor.edit")}}
              >
                <span aria-hidden="true">{{dEmoji preset.emoji}}</span>
                <span
                  class="wiblio-status-preset-editor__label"
                >{{preset.label}}</span>
              </button>
              <DButton
                @icon="xmark"
                @action={{fn this.removePreset preset}}
                @disabled={{@disabled}}
                @translatedTitle={{i18n
                  (themePrefix "wiblio_status_update.editor.remove")
                  label=preset.label
                }}
                class="btn-transparent wiblio-status-preset-editor__remove"
              />
            </li>
          {{/each}}
        </ul>
      {{/if}}

      {{#each (array this.formData) as |formData|}}
        <Form
          @data={{formData}}
          @onSubmit={{this.confirmPreset}}
          class="wiblio-status-preset-editor__form"
          as |form draft|
        >
          <div class="wiblio-status-preset-editor__composer">
            <form.Field
              @name="status"
              @title={{i18n
                (themePrefix "wiblio_status_update.editor.status_text")
              }}
              @type="custom"
              @format="max"
              @showTitle={{false}}
              @showOptional={{false}}
              @disabled={{@disabled}}
              @validate={{this.validateStatus}}
              class="wiblio-status-preset-editor__field"
              as |field|
            >
              <field.Control>
                <StatusPresetInput
                  @id={{field.id}}
                  @status={{field.value}}
                  @onChange={{field.set}}
                  @disabled={{@disabled}}
                  @error={{field.error}}
                  @describedBy={{field.describedBy}}
                />
              </field.Control>
            </form.Field>
            <button
              type="submit"
              disabled={{or @disabled (not (normalizeStatus draft.status))}}
              class="btn btn-primary btn-icon no-text wiblio-status-preset-editor__confirm"
              aria-label={{i18n
                (themePrefix
                  (if
                    this.isEditing
                    "wiblio_status_update.editor.confirm"
                    "wiblio_status_update.editor.add"
                  )
                )
              }}
              title={{i18n
                (themePrefix
                  (if
                    this.isEditing
                    "wiblio_status_update.editor.confirm"
                    "wiblio_status_update.editor.add"
                  )
                )
              }}
            >
              {{dIcon (if this.isEditing "check" "plus")}}
            </button>
          </div>
        </Form>
      {{/each}}

      {{#if this.isEditing}}
        <div class="wiblio-status-preset-editor__edit-actions">
          <DButton
            @icon="chevron-left"
            @title={{themePrefix "wiblio_status_update.editor.move_before"}}
            @action={{fn this.moveSelected -1}}
            @disabled={{or @disabled this.firstSelected}}
            class="btn-default wiblio-status-preset-editor__move-before"
          />
          <DButton
            @icon="chevron-right"
            @title={{themePrefix "wiblio_status_update.editor.move_after"}}
            @action={{fn this.moveSelected 1}}
            @disabled={{or @disabled this.lastSelected}}
            class="btn-default wiblio-status-preset-editor__move-after"
          />
          <DButton
            @label="cancel"
            @action={{this.cancelEdit}}
            class="btn-transparent"
          />
        </div>
      {{/if}}

    </div>
  </template>
}
