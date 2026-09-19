import { createClient } from "@supabase/supabase-js";
import { randomUUID } from "node:crypto";

const STORE_ROW_ID = "primary";

function createEmptyStore() {
  return {
    version: 1,
    users: {},
    sessions: {},
    usageEvents: [],
    accountBrands: {},
    signupSignals: [],
    securityEvents: [],
    generatedFiles: {},
  };
}

export function normalizeStore(value) {
  const empty = createEmptyStore();
  const data = value && typeof value === "object" ? value : {};
  return {
    version: 1,
    users: data.users && typeof data.users === "object" ? data.users : empty.users,
    sessions: data.sessions && typeof data.sessions === "object" ? data.sessions : empty.sessions,
    usageEvents: Array.isArray(data.usageEvents) ? data.usageEvents : empty.usageEvents,
    accountBrands: data.accountBrands && typeof data.accountBrands === "object" ? data.accountBrands : empty.accountBrands,
    signupSignals: Array.isArray(data.signupSignals) ? data.signupSignals : empty.signupSignals,
    securityEvents: Array.isArray(data.securityEvents) ? data.securityEvents : empty.securityEvents,
    generatedFiles: data.generatedFiles && typeof data.generatedFiles === "object" ? data.generatedFiles : empty.generatedFiles,
  };
}

function clientOptions() {
  return {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  };
}

function operationError(error, fallback) {
  const wrapped = new Error(error?.message || fallback);
  wrapped.code = error?.code || "supabase_error";
  wrapped.status = Number(error?.status) || 500;
  return wrapped;
}

export class SupabaseStore {
  static async connect({ url, secretKey }) {
    const client = createClient(url, secretKey, clientOptions());
    const { data, error } = await client
      .from("layera_app_store")
      .select("payload")
      .eq("id", STORE_ROW_ID)
      .maybeSingle();
    if (error) throw operationError(error, "Data Layera tidak dapat dibaca dari Supabase.");
    const store = new SupabaseStore(client, normalizeStore(data?.payload));
    if (!data) await store.persist();
    await store.cleanup();
    return store;
  }

  constructor(client, data) {
    this.client = client;
    this.data = data;
    this.writeQueue = Promise.resolve();
  }

  async persistSnapshot(snapshot) {
    const { error } = await this.client
      .from("layera_app_store")
      .upsert({ id: STORE_ROW_ID, payload: snapshot, updated_at: new Date().toISOString() }, { onConflict: "id" });
    if (error) throw operationError(error, "Data Layera tidak dapat disimpan ke Supabase.");
  }

  async persist() {
    const snapshot = structuredClone(this.data);
    const write = this.writeQueue.then(() => this.persistSnapshot(snapshot));
    this.writeQueue = write.catch(() => {});
    await write;
  }

  async mutate(mutator) {
    const result = mutator(this.data);
    await this.persist();
    return result;
  }

  async replace(value) {
    this.data = normalizeStore(value);
    await this.persist();
  }

  async cleanup() {
    const now = Date.now();
    const securityCutoff = now - 7 * 24 * 60 * 60 * 1000;
    const signalCutoff = now - 90 * 24 * 60 * 60 * 1000;
    let changed = false;
    for (const [tokenHash, session] of Object.entries(this.data.sessions)) {
      if (!session?.expiresAt || Date.parse(session.expiresAt) <= now) {
        delete this.data.sessions[tokenHash];
        changed = true;
      }
    }
    const securityEvents = this.data.securityEvents.filter((event) => Date.parse(event.createdAt) >= securityCutoff);
    const signupSignals = this.data.signupSignals.filter((signal) => Date.parse(signal.createdAt) >= signalCutoff);
    if (securityEvents.length !== this.data.securityEvents.length) {
      this.data.securityEvents = securityEvents;
      changed = true;
    }
    if (signupSignals.length !== this.data.signupSignals.length) {
      this.data.signupSignals = signupSignals;
      changed = true;
    }
    if (changed) await this.persist();
  }
}

export class SupabaseAuth {
  constructor({ url, publishableKey, secretKey }) {
    this.url = url;
    this.publishableKey = publishableKey;
    this.admin = createClient(url, secretKey, clientOptions());
  }

  createPublicClient() {
    return createClient(this.url, this.publishableKey, clientOptions());
  }

  async createUser({ email, password, displayName }) {
    const { data, error } = await this.admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { display_name: displayName },
    });
    if (error) throw operationError(error, "User tidak dapat dibuat di Supabase Auth.");
    return data.user;
  }

  async deleteUser(userId) {
    const { error } = await this.admin.auth.admin.deleteUser(userId);
    if (error) throw operationError(error, "User Supabase tidak dapat dihapus.");
  }

  async signIn(email, password) {
    const client = this.createPublicClient();
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error) throw operationError(error, "Email atau kata sandi tidak cocok.");
    return data.user;
  }

  async updateUser(userId, attributes) {
    const { data, error } = await this.admin.auth.admin.updateUserById(userId, attributes);
    if (error) throw operationError(error, "Detail login tidak dapat diperbarui di Supabase Auth.");
    return data.user;
  }

  async findUserByEmail(email) {
    for (let page = 1; page <= 20; page += 1) {
      const { data, error } = await this.admin.auth.admin.listUsers({ page, perPage: 1000 });
      if (error) throw operationError(error, "Daftar user Supabase tidak dapat dibaca.");
      const match = data.users.find((user) => user.email?.toLowerCase() === email.toLowerCase());
      if (match) return match;
      if (data.users.length < 1000) return null;
    }
    return null;
  }
}

export class MemoryStore {
  constructor() {
    this.data = createEmptyStore();
  }

  async mutate(mutator) {
    return mutator(this.data);
  }
}

export class MemoryAuth {
  constructor() {
    this.users = new Map();
  }

  async createUser({ email, password, displayName }) {
    if ([...this.users.values()].some((user) => user.email === email)) {
      const error = new Error("Email tersebut sudah terdaftar.");
      error.code = "email_exists";
      throw error;
    }
    const user = { id: randomUUID(), email, password, user_metadata: { display_name: displayName } };
    this.users.set(user.id, user);
    return user;
  }

  async deleteUser(userId) {
    this.users.delete(userId);
  }

  async signIn(email, password) {
    const user = [...this.users.values()].find((candidate) => candidate.email === email && candidate.password === password);
    if (!user) throw new Error("Email atau kata sandi tidak cocok.");
    return user;
  }

  async updateUser(userId, attributes) {
    const user = this.users.get(userId);
    if (!user) throw new Error("User tidak ditemukan.");
    if (attributes.password) user.password = attributes.password;
    if (attributes.email) user.email = attributes.email;
    if (attributes.user_metadata) user.user_metadata = { ...user.user_metadata, ...attributes.user_metadata };
    return user;
  }

  async findUserByEmail(email) {
    return [...this.users.values()].find((user) => user.email === email) || null;
  }
}
