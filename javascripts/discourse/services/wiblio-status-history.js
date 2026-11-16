import Service, { service } from "@ember/service";
import { settings } from "virtual:theme";
import KeyValueStore from "discourse/lib/key-value-store";
import { normalizeStatus, sameStatus, statusKey } from "../lib/status-pair";

const HISTORY_LIMIT = 50;

export default class WiblioStatusHistory extends Service {
  @service currentUser;

  store = new KeyValueStore("wiblio_status_update_");
  pendingStatus;

  get storageKey() {
    return `history_v1_${this.currentUser?.id}`;
  }

  get entries() {
    if (!this.currentUser?.id) {
      return [];
    }

    const stored = this.store.getObject(this.storageKey);
    if (!Array.isArray(stored)) {
      return [];
    }

    const pairs = new Map();
    stored.forEach((entry) => {
      const status = normalizeStatus(entry);
      if (
        !status ||
        !Number.isSafeInteger(entry.count) ||
        entry.count < 1 ||
        !Number.isFinite(entry.lastUsed)
      ) {
        return;
      }
      const key = statusKey(status);
      const previous = pairs.get(key);
      pairs.set(key, {
        ...status,
        count: Math.min(
          (previous?.count || 0) + entry.count,
          Number.MAX_SAFE_INTEGER
        ),
        lastUsed: Math.max(previous?.lastUsed ?? -Infinity, entry.lastUsed),
      });
    });
    return [...pairs.values()]
      .sort((a, b) => b.count - a.count || b.lastUsed - a.lastUsed)
      .slice(0, HISTORY_LIMIT);
  }

  stage(status) {
    const pair = normalizeStatus(status);
    this.pendingStatus =
      settings.show_frequent_statuses && pair
        ? { ...pair, userId: this.currentUser?.id }
        : undefined;
  }

  commitPending(userId, status) {
    if (
      userId === this.currentUser?.id &&
      userId === this.pendingStatus?.userId &&
      sameStatus(normalizeStatus(status), this.pendingStatus)
    ) {
      this.record(status);
    }
  }

  clearPending() {
    this.pendingStatus = undefined;
  }

  record(status) {
    this.clearPending();
    if (!settings.show_frequent_statuses || !this.currentUser?.id) {
      return;
    }

    const pair = normalizeStatus(status);
    if (!pair) {
      return;
    }

    const entries = this.entries;
    const previous = entries.find((entry) => sameStatus(entry, pair));
    const updated = [
      {
        ...pair,
        count: Math.min((previous?.count || 0) + 1, Number.MAX_SAFE_INTEGER),
        lastUsed: Date.now(),
      },
      ...entries.filter((entry) => !sameStatus(entry, pair)),
    ]
      .sort((a, b) => b.lastUsed - a.lastUsed)
      .slice(0, HISTORY_LIMIT);

    try {
      this.store.setObject({ key: this.storageKey, value: updated });
    } catch {
      // Browser storage can be unavailable or full; saving a status must still work.
    }
  }

  clear() {
    this.clearPending();
    try {
      this.store.remove(this.storageKey);
    } catch {
      // A browser can deny storage access after the page has loaded.
    }
  }
}
