import {
  click,
  fillIn,
  find,
  findAll,
  render,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { themePrefix } from "virtual:theme";
import ThemeSettingEditor from "discourse/admin/components/theme-setting-editor";
import ThemeSettings from "discourse/admin/models/theme-settings";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import { i18n } from "discourse-i18n";

const THEME_ID = Number(themePrefix("").split(".")[1]);
const EDITOR = ".wiblio-status-preset-editor";
const PRESET = `${EDITOR} .wiblio-status-preset-editor__preset`;
const INPUT = `${EDITOR} .wiblio-status-preset-input__description`;
const CONFIRM = `${EDITOR} .wiblio-status-preset-editor__confirm`;

async function renderEditor(context) {
  const model = context.model;
  const setting = context.setting;
  await render(
    <template>
      <ThemeSettingEditor @model={{model}} @setting={{setting}} />
    </template>
  );
}

function labels() {
  return findAll(`${EDITOR} .wiblio-status-preset-editor__label`).map(
    (element) => element.textContent.trim()
  );
}

module("Integration | Component | StatusPresetEditor", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const presets = [
      { emoji: "coffee", label: "On a break" },
      { emoji: "dart", label: "Focusing" },
      { emoji: "palm_tree", label: "Away" },
    ];
    this.model = { id: THEME_ID };
    this.setting = ThemeSettings.create({
      setting: "status_presets",
      humanized_name: "Status presets",
      type: "objects",
      objects_schema: {
        name: "status",
        properties: { emoji: { type: "string" }, label: { type: "string" } },
      },
      value: presets,
      default: presets,
    });
    this.savedValues = [];
    pretender.put(`/admin/themes/${THEME_ID}/setting`, (request) => {
      const data = new URLSearchParams(request.requestBody);
      this.savedValues.push(JSON.parse(data.get("value")));
      return response({ success: true });
    });
    pretender.get("/emojis/search-aliases.json", () => response([]));
  });

  test("replaces this component's object setting with the inline editor", async function (assert) {
    await renderEditor(this);

    assert.deepEqual(
      labels(),
      ["On a break", "Focusing", "Away"],
      "configured pairs appear in order"
    );
    assert
      .dom(".setting-value-edit-button")
      .doesNotExist("there is no separate editor page button");
    assert.dom(INPUT).hasValue("", "the composer starts empty");
    assert.dom(CONFIRM).isDisabled("an empty pair cannot be added");
  });

  test("leaves another component's setting with the same name unchanged", async function (assert) {
    this.model.id = THEME_ID + 10000;
    await renderEditor(this);

    assert.dom(EDITOR).doesNotExist("another component is unaffected");
    assert
      .dom(".setting-value-edit-button")
      .exists("the standard object editor remains available");
  });

  test("separates the personal history label from its description and preserves save and cancel", async function (assert) {
    this.setting = ThemeSettings.create({
      setting: "show_frequent_statuses",
      humanized_name: "Show frequent statuses",
      type: "bool",
      value: "true",
      default: "true",
      description: "Disabling this does not delete existing history.",
    });
    await renderEditor(this);

    assert
      .dom(".wiblio-status-history-setting")
      .hasText(
        i18n(themePrefix("wiblio_status_update.remember_history")),
        "the checkbox explains that suggestions are personal"
      );
    assert
      .dom(".desc")
      .hasText(this.setting.description, "the retention note is separate");
    assert.dom('input[type="checkbox"]').isChecked("history starts enabled");
    await click('input[type="checkbox"]');
    await click(".setting-controls__cancel");
    assert
      .dom('input[type="checkbox"]')
      .isChecked("cancel restores the saved value");
    assert.strictEqual(this.savedValues.length, 0, "cancel does not save");
    await click('input[type="checkbox"]');
    await click(".setting-controls__ok");
    assert.deepEqual(
      this.savedValues,
      [false],
      "the boolean setting is saved normally"
    );
  });

  test("adds an emoji/text pair to the preview and saves through the setting", async function (assert) {
    await renderEditor(this);
    await click(`${EDITOR} .btn-emoji`);
    await emojiPicker().fill("heart");
    await emojiPicker().select("heart");
    await fillIn(INPUT, "Reading");
    await click(CONFIRM);

    assert.deepEqual(
      labels(),
      ["On a break", "Focusing", "Away", "Reading"],
      "the pair is added to the preview"
    );
    assert.dom(INPUT).hasValue("", "the composer is ready for the next pair");
    assert.strictEqual(
      this.savedValues.length,
      0,
      "adding to the list does not persist the setting yet"
    );

    await click(".setting-controls__ok");

    assert.deepEqual(
      this.savedValues[0].at(-1),
      { emoji: "heart", label: "Reading" },
      "the confirmed pair is saved in the existing format"
    );
    assert
      .dom(".setting-controls__ok")
      .doesNotExist("successful save clears the pending change");
  });

  test("submitting text supplies the core default emoji", async function (assert) {
    await renderEditor(this);
    await fillIn(INPUT, "Writing");
    await triggerEvent(`${EDITOR} form`, "submit");

    assert.deepEqual(
      labels(),
      ["On a break", "Focusing", "Away", "Writing"],
      "submitting adds the pair"
    );
    await click(".setting-controls__ok");
    assert.strictEqual(
      this.savedValues[0].at(-1).emoji,
      "speech_balloon",
      "typing supplies the same default emoji as the core status picker"
    );
  });

  test("clicking a pair edits it in place", async function (assert) {
    await renderEditor(this);
    await click(`${PRESET}:first-child`);
    assert.dom(INPUT).hasValue("On a break", "the chosen text is loaded");
    await fillIn(INPUT, "Taking a break");
    await click(CONFIRM);
    await click(".setting-controls__ok");

    assert.deepEqual(
      labels(),
      ["Taking a break", "Focusing", "Away"],
      "editing retains the original position"
    );
    assert.strictEqual(
      this.savedValues[0][0].emoji,
      "hot_beverage",
      "editing text retains its emoji with its canonical name"
    );
  });

  test("duplicate pairs are rejected", async function (assert) {
    await renderEditor(this);
    await fillIn(INPUT, "Reading");
    await click(CONFIRM);
    await fillIn(INPUT, "Reading");
    await click(CONFIRM);

    assert
      .dom(`${EDITOR} .form-kit__errors-summary`)
      .exists("FormKit reports the duplicate");
    assert.strictEqual(
      labels().length,
      4,
      "the existing pair is not duplicated"
    );
    assert
      .dom(INPUT)
      .hasAttribute(
        "aria-invalid",
        "true",
        "the input exposes its error state"
      );
    const errorId = find(INPUT).getAttribute("aria-describedby");
    assert.ok(errorId, "the input references its error message");
    assert
      .dom(`#${errorId}`)
      .includesText(
        i18n(themePrefix("wiblio_status_update.editor.duplicate")),
        "the referenced error explains the duplicate"
      );
    await fillIn(INPUT, "A different status");
    await click(CONFIRM);
    assert
      .dom(INPUT)
      .doesNotHaveAttribute(
        "aria-invalid",
        "correcting the pair clears the error state"
      );
    assert
      .dom(INPUT)
      .doesNotHaveAttribute(
        "aria-describedby",
        "the input no longer references a removed error"
      );
  });

  test("canonical emoji names cannot duplicate existing aliases", async function (assert) {
    await renderEditor(this);
    await click(`${EDITOR} .btn-emoji`);
    await emojiPicker().fill("hot_beverage");
    await emojiPicker().select("hot_beverage");
    await fillIn(INPUT, "On a break");
    await click(CONFIRM);

    assert
      .dom(`${EDITOR} .form-kit__errors-summary`)
      .exists("the existing alias is recognized");
    assert.strictEqual(
      labels().length,
      3,
      "the same visible pair is not added again"
    );
  });

  test("dragging reorders the preview and the saved array", async function (assert) {
    await renderEditor(this);
    const items = findAll(`${EDITOR} .wiblio-status-preset-editor__item`);
    const dataTransfer = new DataTransfer();
    const bounds = items[2].getBoundingClientRect();
    await triggerEvent(items[0], "dragstart", { dataTransfer });
    await triggerEvent(items[2], "dragover", {
      dataTransfer,
      clientX: bounds.right - 1,
    });
    await triggerEvent(items[2], "drop", { dataTransfer });

    assert.deepEqual(
      labels(),
      ["Focusing", "Away", "On a break"],
      "the dragged pair moves after the target"
    );
    await click(".setting-controls__ok");
    assert.deepEqual(
      this.savedValues[0].map((preset) => preset.label),
      labels(),
      "the preview order is persisted"
    );
  });

  test("Alt and arrow keys leave the preset order unchanged", async function (assert) {
    await renderEditor(this);
    await triggerKeyEvent(find(PRESET), "keydown", "ArrowRight", {
      altKey: true,
    });

    assert.deepEqual(
      labels(),
      ["On a break", "Focusing", "Away"],
      "the removed shortcut leaves the order unchanged"
    );
    assert
      .dom(INPUT)
      .hasValue("", "keyboard sorting leaves the composer unchanged");
  });

  test("selected pairs can be moved with buttons", async function (assert) {
    await renderEditor(this);
    await click(findAll(PRESET)[1]);
    await click(`${EDITOR} .wiblio-status-preset-editor__move-before`);

    assert.deepEqual(
      labels(),
      ["Focusing", "On a break", "Away"],
      "the touch-accessible button moves the pair"
    );
    assert
      .dom(INPUT)
      .hasValue("Focusing", "the selected pair remains selected after moving");
    assert
      .dom(`${EDITOR} .wiblio-status-preset-editor__move-before`)
      .isDisabled("the first pair cannot move earlier");
  });

  test("removing a pair can be undone through the setting cancel control", async function (assert) {
    await renderEditor(this);
    await click(`${EDITOR} .wiblio-status-preset-editor__remove`);
    assert.deepEqual(
      labels(),
      ["Focusing", "Away"],
      "the pair is removed from the preview"
    );
    await click(".setting-controls__cancel");

    assert.deepEqual(
      labels(),
      ["On a break", "Focusing", "Away"],
      "cancel restores the original list"
    );
    assert.strictEqual(
      this.savedValues.length,
      0,
      "cancelling makes no request"
    );
  });

  test("a failed setting save preserves the list for retry", async function (assert) {
    await renderEditor(this);
    await click(`${EDITOR} .wiblio-status-preset-editor__remove`);
    pretender.put(`/admin/themes/${THEME_ID}/setting`, () =>
      response(422, { errors: ["Unavailable"] })
    );
    await click(".setting-controls__ok");

    assert
      .dom(".validation-error")
      .includesText("Unavailable", "the save error is shown");
    assert.deepEqual(
      labels(),
      ["Focusing", "Away"],
      "the preview is retained after the failure"
    );
    assert.dom(".setting-controls__ok").isEnabled("the save can be retried");
  });

  test("an empty list can be filled and saved", async function (assert) {
    this.setting.set("value", []);
    this.setting.rollback();
    await renderEditor(this);
    await fillIn(INPUT, "The first status");
    await click(CONFIRM);
    await click(".setting-controls__ok");

    assert.deepEqual(
      labels(),
      ["The first status"],
      "the first pair appears in the preview"
    );
    assert.deepEqual(
      this.savedValues[0],
      [{ emoji: "speech_balloon", label: "The first status" }],
      "the new list is persisted"
    );
  });

  test("preset labels are escaped", async function (assert) {
    this.setting.set("value", [{ emoji: "heart", label: "<img src=x>" }]);
    this.setting.rollback();
    await renderEditor(this);

    assert
      .dom(`${EDITOR} .wiblio-status-preset-editor__label`)
      .hasText("<img src=x>", "the label appears as plain text");
    assert
      .dom(`${EDITOR} img:not(.emoji)`)
      .doesNotExist("label markup is never interpreted");
  });
});
