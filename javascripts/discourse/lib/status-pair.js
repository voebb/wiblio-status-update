import { normalizeEmoji } from "pretty-text/emoji";
import { emojiUrlFor } from "discourse/lib/text";

function statusEmoji(emoji) {
  if (typeof emoji !== "string") {
    return;
  }
  const code = emoji.trim().replace(/^:|:$/g, "").toLowerCase();
  return (
    normalizeEmoji(code) ||
    code.replace(
      /^([^:]+)(:t[2-6])$/,
      (_, base, tone) => `${normalizeEmoji(base) || base}${tone}`
    )
  );
}

export function normalizeStatus(status) {
  if (
    typeof status?.emoji !== "string" ||
    typeof status?.description !== "string"
  ) {
    return;
  }

  const emoji = statusEmoji(status.emoji);
  const description = status.description.trim();
  if (
    !emoji ||
    !description ||
    [...description].length > 100 ||
    !emojiUrlFor(emoji)
  ) {
    return;
  }

  return { emoji, description };
}

export function statusKey(status) {
  return JSON.stringify([statusEmoji(status.emoji), status.description]);
}

export function sameStatus(first, second) {
  return (
    statusEmoji(first?.emoji) === statusEmoji(second?.emoji) &&
    first?.description === second?.description
  );
}
