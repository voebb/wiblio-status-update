import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { themePrefix } from "virtual:theme";
import EmojiPicker from "discourse/components/emoji-picker";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class StatusPresetInput extends Component {
  @action
  selectEmoji(emoji) {
    this.args.onChange({ ...this.args.status, emoji });
  }

  @action
  updateDescription(event) {
    this.args.onChange({
      emoji: this.args.status.emoji || "speech_balloon",
      description: event.target.value,
    });
  }

  <template>
    <div class="wiblio-status-preset-input" ...attributes>
      <EmojiPicker
        @emoji={{@status.emoji}}
        @didSelectEmoji={{this.selectEmoji}}
        @btnClass="btn-emoji btn-transparent"
        @modalForMobile={{false}}
        @context={{if @context @context "wiblio-status-presets"}}
        @inline={{true}}
        @disabled={{@disabled}}
      />
      <input
        {{on "input" this.updateDescription}}
        {{(if @autofocus dAutoFocus)}}
        id={{@id}}
        value={{@status.description}}
        type="text"
        maxlength="100"
        autocomplete="off"
        disabled={{@disabled}}
        aria-invalid={{if @error "true"}}
        aria-describedby={{@describedBy}}
        aria-label={{i18n
          (themePrefix "wiblio_status_update.editor.status_text")
        }}
        placeholder={{if
          @placeholder
          @placeholder
          (i18n (themePrefix "wiblio_status_update.editor.status_text"))
        }}
        class={{dConcatClass
          "wiblio-status-preset-input__description"
          @inputClass
        }}
      />
    </div>
  </template>
}
