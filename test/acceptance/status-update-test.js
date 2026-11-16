import { click, fillIn, findAll, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { settings } from "virtual:theme";
import DoNotDisturbModal from "discourse/components/modal/do-not-disturb";
import KeyValueStore from "discourse/lib/key-value-store";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

const MODAL = ".wiblio-status-update";
const PRESETS = '[data-status-section="presets"]';
const FREQUENT = '[data-status-section="frequent"]';
const CHOICE = ".wiblio-status-suggestions__button";
const SAVE = `${MODAL} .d-modal__footer .btn-primary`;
const PAIR = { emoji: "hot_beverage", description: "On a break" };

async function openStatus() {
  await click(".header-dropdown-toggle.current-user button");
  await click("#user-menu-button-profile");
  await click(".set-user-status button");
}

async function choosePreset() {
  await click(`${PRESETS} [data-status-emoji="hot_beverage"]`);
}

acceptance("Wiblio status update", function (needs) {
  let requests;

  needs.user({ id: 19, username: "eviltrout", status: null });
  needs.settings({ enable_user_status: true });

  needs.hooks.beforeEach(function () {
    this.originalSettings = {
      status_presets: settings.status_presets,
      show_frequent_statuses: settings.show_frequent_statuses,
      frequent_status_limit: settings.frequent_status_limit,
    };
    settings.status_presets = [
      { emoji: "coffee", label: "On a break" },
      { emoji: "dart", label: "Focusing" },
    ];
    settings.show_frequent_statuses = true;
    settings.frequent_status_limit = 5;
    this.historyStore = new KeyValueStore("wiblio_status_update_");
    this.historyStore.removeKeys();
    requests = [];
  });

  needs.hooks.afterEach(function () {
    Object.assign(settings, this.originalSettings);
    this.historyStore.removeKeys();
  });

  needs.pretender((server, helper) => {
    server.put("/user-status.json", (request) => {
      requests.push(new URLSearchParams(request.requestBody));
      return helper.response({ success: true });
    });
    server.delete("/user-status.json", () =>
      helper.response({ success: true })
    );
    server.post("/do-not-disturb.json", (request) => {
      const duration = new URLSearchParams(request.requestBody).get("duration");
      return helper.response({
        ends_at: moment.utc().add(Number(duration), "minutes").toISOString(),
      });
    });
    server.delete("/do-not-disturb.json", () =>
      helper.response({ success: true })
    );
    server.get("/emojis/search-aliases.json", () => helper.response([]));
    server.put("/u/eviltrout.json", () => helper.response({ user: {} }));
  });

  test("shortcuts prefill an editable status without saving", async function (assert) {
    await visit("/latest");
    await openStatus();

    assert
      .dom(`${PRESETS} ${CHOICE}`)
      .exists({ count: 2 }, "both shortcuts appear");
    assert.dom(SAVE).isDisabled("an empty status cannot be saved");
    await choosePreset();

    assert
      .dom(".user-status-description")
      .hasValue(PAIR.description, "text is filled in");
    assert
      .dom(".btn-emoji img.emoji")
      .hasAttribute("title", PAIR.emoji, "emoji is filled in");
    assert
      .dom(`${PRESETS} [data-status-emoji="hot_beverage"]`)
      .hasAttribute("aria-pressed", "true", "selection is accessible");
    assert.strictEqual(requests.length, 0, "selection does not send a request");

    await fillIn(".user-status-description", "Taking a longer break");
    await click(SAVE);

    assert.strictEqual(
      requests[0].get("description"),
      "Taking a longer break",
      "edited text is saved"
    );
    assert.strictEqual(
      requests[0].get("emoji"),
      PAIR.emoji,
      "the chosen emoji is saved"
    );
    assert.dom(MODAL).doesNotExist("successful save closes the dialog");
  });

  test("custom emoji and text remain available without presets", async function (assert) {
    settings.status_presets = [];
    await visit("/latest");
    await openStatus();
    await click(".btn-emoji");
    await emojiPicker().fill("heart");
    await emojiPicker().select("heart");
    await fillIn(".user-status-description", "Reading a book");
    await click(SAVE);

    assert.strictEqual(
      requests[0].get("emoji"),
      "heart",
      "a custom emoji is saved"
    );
    assert.strictEqual(
      requests[0].get("description"),
      "Reading a book",
      "custom text is saved"
    );
  });

  test("cancelling preserves the original status and does not count a use", async function (assert) {
    updateCurrentUser({ status: { emoji: "heart", description: "Reading" } });
    await visit("/latest");
    await openStatus();
    await choosePreset();
    await click(`${MODAL} .d-modal-cancel`);
    await openStatus();

    assert
      .dom(".user-status-description")
      .hasValue("Reading", "the original status is retained");
    assert.strictEqual(requests.length, 0, "no status is saved");
    assert.deepEqual(
      this.owner.lookup("service:wiblio-status-history").entries,
      [],
      "cancel does not enter history"
    );
  });

  test("successful custom saves become frequent suggestions", async function (assert) {
    await visit("/latest");
    await openStatus();
    await choosePreset();
    await fillIn(".user-status-description", "Coffee with a book");
    await click(SAVE);
    await openStatus();

    assert
      .dom(`${FREQUENT} ${CHOICE}`)
      .hasText("Coffee with a book", "saved custom text is suggested");
    await click(`${FREQUENT} ${CHOICE}`);
    assert
      .dom(".user-status-description")
      .hasValue("Coffee with a book", "the frequent pair can be selected");
  });

  test("failed saves do not enter history and remain editable", async function (assert) {
    pretender.put("/user-status.json", () =>
      response(422, { errors: ["Unavailable"] })
    );
    await visit("/latest");
    await openStatus();
    await choosePreset();
    await click(SAVE);

    assert
      .dom(".user-status-description")
      .hasValue(PAIR.description, "input survives a failed save");
    assert.deepEqual(
      this.owner.lookup("service:wiblio-status-history").entries,
      [],
      "failed saves do not count"
    );
  });

  test("frequent pairs are ranked, limited, and do not duplicate fixed shortcuts", async function (assert) {
    settings.frequent_status_limit = 2;
    await visit("/latest");
    this.historyStore.setObject({
      key: "history_v1_19",
      value: [
        { ...PAIR, count: 10, lastUsed: 1 },
        { emoji: "heart", description: "Reading", count: 2, lastUsed: 2 },
        { emoji: "dart", description: "Writing", count: 1, lastUsed: 3 },
        { emoji: "palm_tree", description: "Away", count: 1, lastUsed: 4 },
      ],
    });
    await openStatus();

    assert.deepEqual(
      findAll(`${FREQUENT} ${CHOICE}`).map((button) =>
        button.textContent.trim()
      ),
      ["Reading", "Away"],
      "frequency wins, then recency; fixed pairs and excess suggestions are omitted"
    );
    assert
      .dom(`${PRESETS} ${CHOICE}`)
      .exists({ count: 2 }, "fixed shortcuts retain their order and count");
  });

  test("historical emoji aliases share counts and do not duplicate presets", async function (assert) {
    this.historyStore.setObject({
      key: "history_v1_19",
      value: [
        { ...PAIR, emoji: "coffee", count: 2, lastUsed: 1 },
        { ...PAIR, count: 3, lastUsed: 2 },
      ],
    });
    await visit("/latest");
    await openStatus();
    assert
      .dom(FREQUENT)
      .doesNotExist("the fixed preset covers both stored names");
    await choosePreset();
    await click(SAVE);
    const entries = this.historyStore.getObject("history_v1_19");
    assert.strictEqual(entries.length, 1, "the aliases are stored as one pair");
    assert.strictEqual(
      entries[0].count,
      6,
      "both previous counts and the new use are retained"
    );
    assert.strictEqual(
      entries[0].emoji,
      "hot_beverage",
      "the canonical name is stored"
    );
  });

  test("history is kept separate for each account", async function (assert) {
    this.historyStore.setObject({
      key: "history_v1_20",
      value: [
        {
          emoji: "heart",
          description: "Another account",
          count: 10,
          lastUsed: 1,
        },
      ],
    });
    await visit("/latest");
    await openStatus();

    assert
      .dom(FREQUENT)
      .doesNotExist("another account's history is not displayed");
    await choosePreset();
    await click(SAVE);
    assert.strictEqual(
      this.historyStore.getObject("history_v1_20")[0].count,
      10,
      "another account's history is untouched"
    );
    assert.strictEqual(
      this.historyStore.getObject("history_v1_19")[0].count,
      1,
      "this account has its own history"
    );
  });

  test("new pairs can become frequent even after the history reaches its limit", async function (assert) {
    this.historyStore.setObject({
      key: "history_v1_19",
      value: Array.from({ length: 50 }, (_, index) => ({
        emoji: "heart",
        description: `Saved status ${index}`,
        count: 2,
        lastUsed: index + 1,
      })),
    });
    await visit("/latest");
    const history = this.owner.lookup("service:wiblio-status-history");
    const newPair = { emoji: "book", description: "A new favorite" };
    history.record(newPair);
    history.record(newPair);
    history.record(newPair);

    assert.strictEqual(history.entries.length, 50, "history remains bounded");
    assert.strictEqual(
      history.entries[0].description,
      newPair.description,
      "a new pair can overtake older favorites"
    );
    assert.strictEqual(
      history.entries[0].count,
      3,
      "successive uses accumulate"
    );
    assert.false(
      history.entries.some((entry) => entry.description === "Saved status 0"),
      "the least recently used pair is discarded"
    );
  });

  test("clearing history leaves the status and presets intact", async function (assert) {
    await visit("/latest");
    await openStatus();
    await choosePreset();
    await click(SAVE);
    await openStatus();
    await click(".wiblio-status-suggestions__clear");

    assert
      .dom(".user-status-description")
      .hasValue(PAIR.description, "current status remains");
    assert.dom(`${PRESETS} ${CHOICE}`).exists({ count: 2 }, "presets remain");
    assert
      .dom(".wiblio-status-suggestions__clear")
      .doesNotExist("history is empty");
    assert.notOk(
      this.historyStore.getObject("history_v1_19"),
      "stored history is removed"
    );
  });

  test("disabling frequent statuses stops recording and displaying them", async function (assert) {
    this.historyStore.setObject({
      key: "history_v1_19",
      value: [
        { emoji: "heart", description: "Reading", count: 1, lastUsed: 1 },
      ],
    });
    settings.show_frequent_statuses = false;
    await visit("/latest");
    await openStatus();
    assert.dom(FREQUENT).doesNotExist("frequent suggestions are hidden");
    await choosePreset();
    await click(SAVE);

    assert.strictEqual(
      this.historyStore.getObject("history_v1_19").length,
      1,
      "existing history is preserved without recording"
    );
    assert.strictEqual(
      this.historyStore.getObject("history_v1_19")[0].description,
      "Reading",
      "saved pair was not recorded"
    );
  });

  test("account preferences count only after the page save succeeds", async function (assert) {
    await visit("/u/eviltrout/preferences/account");
    await click(".pref-user-status .btn-default");
    await choosePreset();
    assert
      .dom(".pause-notifications")
      .doesNotExist("account preferences retain core notification behavior");
    await click(SAVE);

    const history = this.owner.lookup("service:wiblio-status-history");
    assert.deepEqual(
      history.entries,
      [],
      "confirming the dialog does not yet persist history"
    );
    await click(".save-changes");
    assert.strictEqual(
      history.entries[0]?.count,
      1,
      "a successful page save counts once"
    );
    await click(".save-changes");
    assert.strictEqual(
      history.entries[0]?.count,
      1,
      "saving unrelated preferences again does not count twice"
    );
  });

  test("failed account saves can be retried without counting the failure", async function (assert) {
    await visit("/u/eviltrout/preferences/account");
    await click(".pref-user-status .btn-default");
    await choosePreset();
    await click(SAVE);
    pretender.put("/u/eviltrout.json", () =>
      response(422, { errors: ["Unavailable"] })
    );
    await click(".save-changes");
    const history = this.owner.lookup("service:wiblio-status-history");
    assert.deepEqual(history.entries, [], "a failed page save does not count");

    await click(".dialog-container .btn-primary");
    pretender.put("/u/eviltrout.json", () => response({ user: {} }));
    await click(".save-changes");
    assert.strictEqual(
      history.entries[0]?.count,
      1,
      "retrying successfully counts once"
    );
  });

  test("deleting a status does not create history", async function (assert) {
    updateCurrentUser({ status: PAIR });
    await visit("/latest");
    await openStatus();
    await click(`${MODAL} .delete-status`);
    await openStatus();

    assert
      .dom(".user-status-description")
      .hasValue("", "the status is deleted");
    assert
      .dom(`${MODAL} .delete-status`)
      .doesNotExist("there is no status to delete");
    assert.deepEqual(
      this.owner.lookup("service:wiblio-status-history").entries,
      [],
      "deletion is not a status use"
    );
  });

  test("shortcuts retain expiration and notification pausing", async function (assert) {
    await visit("/latest");
    await openStatus();
    await choosePreset();
    await click("#tap_tile_one_hour");
    await click(".pause-notifications input[type=checkbox]");
    await click(SAVE);

    const remainingMinutes = moment
      .utc(requests[0].get("ends_at"))
      .diff(moment.utc(), "minutes");
    assert.true(remainingMinutes >= 59, "the expiration is sent to core");
    assert.true(
      remainingMinutes <= 60,
      "the expiration is at most one hour away"
    );
    assert
      .dom(".do-not-disturb-background .d-icon-discourse-dnd")
      .exists("core activates notification pausing");
  });

  test("invalid and duplicate presets are omitted and labels are escaped", async function (assert) {
    settings.status_presets = [
      { emoji: "coffee", label: "On a break" },
      { emoji: ":coffee:", label: "On a break" },
      { emoji: "hot_beverage", label: "On a break" },
      { emoji: " :COFFEE: ", label: "On a break" },
      { emoji: "not_a_real_status_emoji", label: "Invalid" },
      { emoji: "heart", label: " " },
      { emoji: "heart", label: '<img src=x onerror="alert(1)">' },
    ];
    await visit("/latest");
    await openStatus();

    assert
      .dom(`${PRESETS} ${CHOICE}`)
      .exists({ count: 2 }, "only valid unique presets appear");
    assert
      .dom(`${PRESETS} [data-status-emoji="heart"]`)
      .hasText('<img src=x onerror="alert(1)">', "labels render as text");
    assert
      .dom(`${PRESETS} img:not(.emoji)`)
      .doesNotExist("label markup is not interpreted");
  });

  test("skin tone aliases share one preset while retaining the selected tone", async function (assert) {
    settings.status_presets = [
      { emoji: "thumbsup:t2", label: "Available" },
      { emoji: "thumbs_up:t2", label: "Available" },
    ];
    await visit("/latest");
    await openStatus();
    assert
      .dom(`${PRESETS} ${CHOICE}`)
      .exists({ count: 1 }, "tone aliases share a preset");
    await click(`${PRESETS} ${CHOICE}`);
    await click(SAVE);
    assert.strictEqual(
      requests[0].get("emoji"),
      "+1:t2",
      "the tone survives normalization and saving"
    );
  });

  test("corrupt local history is ignored", async function (assert) {
    this.historyStore.set({ key: "history_v1_19", value: "not JSON" });
    await visit("/latest");
    await openStatus();
    await choosePreset();
    await click(SAVE);

    assert.strictEqual(
      this.historyStore.getObject("history_v1_19")[0].count,
      1,
      "normal saves recover from corrupt history"
    );
  });

  test("unrelated modals retain their core behavior", async function (assert) {
    await visit("/latest");
    this.owner.lookup("service:modal").show(DoNotDisturbModal);
    await click(".do-not-disturb-modal .modal-close");

    assert.dom(MODAL).doesNotExist("another modal is not substituted");
    assert
      .dom(".do-not-disturb-modal")
      .doesNotExist("its normal close action works");
  });

  test("a disabled core status feature has no status entry point", async function (assert) {
    this.siteSettings.enable_user_status = false;
    await visit("/latest");
    await click(".header-dropdown-toggle.current-user button");
    await click("#user-menu-button-profile");

    assert
      .dom(".set-user-status")
      .doesNotExist("the component respects the site setting");
  });
});
