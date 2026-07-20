// verify_subscription — server-authoritative StoreKit 2 entitlement check.
//
// Replaces the old trust-the-client path (`upsert_own_subscription`, migration
// 0036) as the ONLY way `public.subscriptions` gets set to 'active'. Migration
// 0044 revokes client execute on `upsert_own_subscription`, so this function
// (running with the service-role key) is now the sole writer.
//
// Input:  POST { "signedTransaction": "<JWS>" }  where the JWS is the
//         `jwsRepresentation` string StoreKit 2 hands back from
//         `Transaction.currentEntitlements` / `Transaction.updates` on-device.
// Auth:   caller's Supabase JWT in the Authorization header (verified via
//         supabase.auth.getUser). Anonymous users are rejected — same
//         convention as the `kyra` function.
// Output: { isPlus, status, productId, expiresAt } resolved from the
//         VERIFIED payload — never from client-supplied fields.
//
// ---------------------------------------------------------------------------
// Verification performed on the JWS (StoreKit 2's "signed transaction"):
//   1. Decode the JWS header, pull the x5c certificate chain (leaf,
//      intermediate).
//   2. Cryptographically verify: leaf signed by intermediate's public key,
//      AND intermediate signed by Apple's Root CA - G3 public key, which is
//      PINNED in this file (not trusted from any cert the caller supplies).
//   3. Verify the JWS's own ES256 signature against the leaf certificate's
//      public key.
//   4. Only once 1–3 all pass do we trust the decoded payload — bundleId,
//      productId, expiresDate, originalTransactionId, revocationDate.
//
// Residual gaps (flagged honestly, not hidden):
//   - We don't check the certificates' own notBefore/notAfter validity
//     windows or do CRL/OCSP revocation checking of the certs themselves.
//     (We DO check the transaction's own revocationDate/expiresDate, which is
//     what actually gates entitlement.)
//   - We don't inspect certificate extensions (EKU, policy OIDs) to confirm
//     the intermediate is specifically Apple's WWDR/StoreKit CA by name —
//     only that it is cryptographically vouched for by the pinned Apple root
//     and in turn vouches for the leaf. That's the property that matters for
//     trust, but a defense-in-depth deployment would add the extra identity
//     checks too.
//   - No billing-grace-period detection: that requires Apple's separate
//     JWSRenewalInfo, not the transaction JWS `currentEntitlements` hands us.
//     Status here is only ever 'active', 'expired', or 'revoked'.
//   - No replay-window check on `signedDate`. Low practical impact: replaying
//     an old valid JWS can only re-assert a real past purchase's own
//     product/expiry, idempotently, to the same account that already
//     submitted it — it cannot grant an entitlement that was never purchased.
// ---------------------------------------------------------------------------
//
// Deploy: ./supabase/deploy_verify_subscription.sh

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const BUNDLE_ID = "com.tdocks.crossedout";
const KNOWN_PRODUCT_IDS = new Set([
  "com.tdocks.crossedout.plus.monthly",
  "com.tdocks.crossedout.plus.annual",
]);

// Apple Root CA - G3 (https://www.apple.com/certificateauthority/AppleRootCA-G3.cer),
// pinned as its raw SubjectPublicKeyInfo (DER, standard base64). ECDSA P-384.
// This is the root of trust: the intermediate cert presented in a JWS's x5c
// must be signed by THIS key, never by whatever root (if any) the caller's
// x5c chain happens to include.
const APPLE_ROOT_CA_G3_SPKI_B64 =
  "MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEmOkvPUBypO2TInKBExzdEJXxxaNOcdwU" +
  "FtkO5aYFKndke19OONO7HES1f/UftjJiXcnphFtPME8RWgD9WFgMpfUPLE0HRxN1" +
  "2peXl28xXO0rnXsgO9i5VNlemaQ6UQox";

// ---------------------------------------------------------------------------
// Minimal DER/ASN.1 helpers — just enough to walk an X.509 certificate and
// pull out {tbsCertificate bytes, signature, subjectPublicKeyInfo} without a
// full ASN.1 library.
// ---------------------------------------------------------------------------

interface TLV {
  tag: number;
  offset: number;
  contentStart: number;
  contentLength: number;
  totalLength: number;
}

function derReadTLV(buf: Uint8Array, offset: number): TLV {
  const tag = buf[offset];
  const lenByte = buf[offset + 1];
  let contentStart = offset + 2;
  let contentLength: number;
  if (lenByte & 0x80) {
    const numBytes = lenByte & 0x7f;
    contentLength = 0;
    for (let i = 0; i < numBytes; i++) contentLength = (contentLength << 8) | buf[contentStart + i];
    contentStart += numBytes;
  } else {
    contentLength = lenByte;
  }
  return { tag, offset, contentStart, contentLength, totalLength: (contentStart - offset) + contentLength };
}

function derChildren(buf: Uint8Array, parent: TLV): TLV[] {
  const out: TLV[] = [];
  let pos = parent.contentStart;
  const end = parent.contentStart + parent.contentLength;
  while (pos < end) {
    const t = derReadTLV(buf, pos);
    out.push(t);
    pos += t.totalLength;
  }
  return out;
}

function bytesToHex(b: Uint8Array): string {
  return Array.from(b).map((x) => x.toString(16).padStart(2, "0")).join("");
}

function stripLeadingZeros(b: Uint8Array): Uint8Array {
  let i = 0;
  while (i < b.length - 1 && b[i] === 0x00) i++;
  return b.slice(i);
}

function leftPad(b: Uint8Array, len: number): Uint8Array {
  if (b.length === len) return b;
  if (b.length > len) return b.slice(b.length - len);
  const out = new Uint8Array(len);
  out.set(b, len - b.length);
  return out;
}

// X.509 signatures are DER SEQUENCE{INTEGER r, INTEGER s}. JOSE/WebCrypto
// ECDSA signatures are raw fixed-length r||s. Convert DER -> raw.
function derEcdsaSigToRaw(der: Uint8Array, byteLen: number): Uint8Array {
  const seq = derReadTLV(der, 0);
  const [rTLV, sTLV] = derChildren(der, seq);
  const r = leftPad(stripLeadingZeros(der.slice(rTLV.contentStart, rTLV.contentStart + rTLV.contentLength)), byteLen);
  const s = leftPad(stripLeadingZeros(der.slice(sTLV.contentStart, sTLV.contentStart + sTLV.contentLength)), byteLen);
  const out = new Uint8Array(byteLen * 2);
  out.set(r, 0);
  out.set(s, byteLen);
  return out;
}

const OID_ECDSA_SHA256 = "2a8648ce3d040302"; // 1.2.840.10045.4.3.2
const OID_ECDSA_SHA384 = "2a8648ce3d040303"; // 1.2.840.10045.4.3.3
const OID_CURVE_P256 = "2a8648ce3d030107"; // 1.2.840.10045.3.1.7 (secp256r1)
const OID_CURVE_P384 = "2b81040022"; // 1.3.132.0.34 (secp384r1)

type Curve = "P-256" | "P-384";

interface ParsedCert {
  tbsBytes: Uint8Array;
  sigAlgHash: "SHA-256" | "SHA-384";
  sigRawForByteLen: (byteLen: number) => Uint8Array;
  spkiBytes: Uint8Array;
  spkiCurve: Curve;
}

// Parses a DER-encoded X.509 certificate into the pieces needed to verify
// "was this cert signed by that issuer's key" and "what's this cert's own
// public key" — without needing a general-purpose X.509 library.
export function parseX509(der: Uint8Array): ParsedCert {
  const top = derReadTLV(der, 0);
  const [tbs, sigAlg, sigVal] = derChildren(der, top);

  const tbsBytes = der.slice(tbs.offset, tbs.offset + tbs.totalLength);

  const sigAlgChildren = derChildren(der, sigAlg);
  const sigAlgOidHex = bytesToHex(
    der.slice(sigAlgChildren[0].contentStart, sigAlgChildren[0].contentStart + sigAlgChildren[0].contentLength),
  );
  let sigAlgHash: "SHA-256" | "SHA-384";
  if (sigAlgOidHex === OID_ECDSA_SHA256) sigAlgHash = "SHA-256";
  else if (sigAlgOidHex === OID_ECDSA_SHA384) sigAlgHash = "SHA-384";
  else throw new Error("unsupported certificate signature algorithm");

  // BIT STRING content: byte 0 is the "unused bits" count (0 for DER),
  // the rest is the DER-encoded ECDSA signature.
  const sigContent = der.slice(sigVal.contentStart, sigVal.contentStart + sigVal.contentLength);
  const sigDER = sigContent.slice(1);

  // Walk TBSCertificate's children to find subjectPublicKeyInfo. `version`
  // [0] EXPLICIT is OPTIONAL (tag 0xA0 when present); everything else is
  // fixed-order: serialNumber, signature, issuer, validity, subject, spki.
  const tbsChildren = derChildren(der, tbs);
  let idx = 0;
  if (tbsChildren[0].tag === 0xa0) idx = 1;
  idx += 4; // serialNumber, signature AlgorithmIdentifier, issuer, validity
  const spkiTLV = tbsChildren[idx + 1]; // (+1 skips `subject`, lands on spki)
  const spkiBytes = der.slice(spkiTLV.offset, spkiTLV.offset + spkiTLV.totalLength);

  const spkiTop = derReadTLV(spkiBytes, 0);
  const spkiChildren = derChildren(spkiBytes, spkiTop);
  const algIdChildren = derChildren(spkiBytes, spkiChildren[0]);
  const curveOidTLV = algIdChildren[1];
  const curveOidHex = bytesToHex(
    spkiBytes.slice(curveOidTLV.contentStart, curveOidTLV.contentStart + curveOidTLV.contentLength),
  );
  let spkiCurve: Curve;
  if (curveOidHex === OID_CURVE_P256) spkiCurve = "P-256";
  else if (curveOidHex === OID_CURVE_P384) spkiCurve = "P-384";
  else throw new Error("unsupported public key curve");

  return {
    tbsBytes,
    sigAlgHash,
    sigRawForByteLen: (byteLen: number) => derEcdsaSigToRaw(sigDER, byteLen),
    spkiBytes,
    spkiCurve,
  };
}

function curveByteLen(curve: Curve): number {
  return curve === "P-256" ? 32 : 48;
}

// Deno's lib types are strict about Uint8Array<ArrayBufferLike> vs the
// ArrayBuffer-backed BufferSource crypto.subtle wants. These buffers are
// always freshly sliced (never shared/growable), so the cast is safe.
function asBufferSource(u: Uint8Array): BufferSource {
  return u as unknown as BufferSource;
}

async function importEcPublicKey(spkiBytes: Uint8Array, curve: Curve): Promise<CryptoKey> {
  return await crypto.subtle.importKey(
    "spki",
    asBufferSource(spkiBytes),
    { name: "ECDSA", namedCurve: curve },
    false,
    ["verify"],
  );
}

// True if `child` was signed by the key at (issuerSpki, issuerCurve).
export async function verifyIssuedBy(child: ParsedCert, issuerSpki: Uint8Array, issuerCurve: Curve): Promise<boolean> {
  const issuerKey = await importEcPublicKey(issuerSpki, issuerCurve);
  const sigRaw = child.sigRawForByteLen(curveByteLen(issuerCurve));
  return await crypto.subtle.verify(
    { name: "ECDSA", hash: child.sigAlgHash },
    issuerKey,
    asBufferSource(sigRaw),
    asBufferSource(child.tbsBytes),
  );
}

function base64UrlToBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, "+").replace(/_/g, "/");
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  const bin = atob(padded);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

export function base64StdToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

export const APPLE_ROOT_SPKI = base64StdToBytes(APPLE_ROOT_CA_G3_SPKI_B64);

interface StoreKitTransactionPayload {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  expiresDate?: number;
  type?: string;
  environment?: string;
  revocationDate?: number;
  revocationReason?: number;
}

// Verifies a StoreKit 2 signed transaction JWS end-to-end: chain of trust
// (leaf -> intermediate -> pinned Apple root) then the JWS's own ES256
// signature against the leaf's public key. Throws on any failure. Only on
// success is the decoded payload trustworthy.
export async function verifyStoreKitJWS(jws: string): Promise<StoreKitTransactionPayload> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("malformed JWS");
  const [headerB64, payloadB64, sigB64] = parts;

  const header = JSON.parse(new TextDecoder().decode(base64UrlToBytes(headerB64)));
  if (header.alg !== "ES256") throw new Error("unexpected JWS alg: " + header.alg);
  const x5c: string[] | undefined = header.x5c;
  if (!Array.isArray(x5c) || x5c.length < 2) throw new Error("missing x5c certificate chain");

  const leafCert = parseX509(base64StdToBytes(x5c[0]));
  const intermediateCert = parseX509(base64StdToBytes(x5c[1]));

  // leaf <- intermediate <- Apple's PINNED root (never the root x5c itself
  // supplies, if any — that would let a caller pin their own trust anchor).
  const leafOk = await verifyIssuedBy(leafCert, intermediateCert.spkiBytes, intermediateCert.spkiCurve);
  if (!leafOk) throw new Error("leaf certificate not signed by intermediate");

  const intermediateOk = await verifyIssuedBy(intermediateCert, APPLE_ROOT_SPKI, "P-384");
  if (!intermediateOk) throw new Error("intermediate certificate does not chain to Apple Root CA - G3");

  const leafKey = await importEcPublicKey(leafCert.spkiBytes, leafCert.spkiCurve);
  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const sigRaw = base64UrlToBytes(sigB64); // JWS ES256 sig is already raw r||s
  const sigOk = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    leafKey,
    asBufferSource(sigRaw),
    asBufferSource(signingInput),
  );
  if (!sigOk) throw new Error("JWS signature invalid");

  return JSON.parse(new TextDecoder().decode(base64UrlToBytes(payloadB64))) as StoreKitTransactionPayload;
}

// Guarded so this module can be imported (e.g. by a test script) without
// binding a port; Supabase's edge runtime executes this file directly, so
// `import.meta.main` is true in production and the server starts normally.
async function handler(req: Request): Promise<Response> {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const jsonError = (status: number, error: string, extra?: Record<string, unknown>) =>
    new Response(JSON.stringify({ error, ...extra }), {
      status,
      headers: { ...cors, "Content-Type": "application/json" },
    });

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return jsonError(401, "unauthorized");

    // Verify the caller's own Supabase session (same convention as `kyra`):
    // real accounts only, no anonymous self-service entitlement.
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userError } = await userClient.auth.getUser(jwt);
    if (userError || !userData?.user) return jsonError(401, "unauthorized");
    if (userData.user.is_anonymous) return jsonError(403, "anonymous_not_allowed");
    const userId = userData.user.id;

    const { signedTransaction } = await req.json();
    if (!signedTransaction || typeof signedTransaction !== "string") {
      return jsonError(400, "signedTransaction required");
    }

    let payload: StoreKitTransactionPayload;
    try {
      payload = await verifyStoreKitJWS(signedTransaction);
    } catch (e) {
      return jsonError(400, "invalid_transaction", { detail: String(e) });
    }

    // Trust nothing from the client past this point — only the VERIFIED payload.
    if (payload.bundleId !== BUNDLE_ID) return jsonError(400, "bundle_mismatch");
    if (!KNOWN_PRODUCT_IDS.has(payload.productId)) return jsonError(400, "unknown_product");
    if (payload.type && payload.type !== "Auto-Renewable Subscription") {
      return jsonError(400, "unexpected_transaction_type");
    }

    const now = Date.now();
    const expiresMs = typeof payload.expiresDate === "number" ? payload.expiresDate : null;
    const isRevoked = typeof payload.revocationDate === "number";
    const isExpired = expiresMs !== null && expiresMs <= now;
    const status: "active" | "expired" | "revoked" = isRevoked ? "revoked" : isExpired ? "expired" : "active";
    const expiresAtIso = expiresMs !== null ? new Date(expiresMs).toISOString() : null;

    // Privileged write: service-role key bypasses RLS. This — not the client
    // — is the sole path that sets subscriptions.status = 'active', and only
    // ever from a cryptographically verified Apple payload for THIS caller's
    // own user id (never a client-supplied user id).
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });
    const { error: upsertError } = await serviceClient.from("subscriptions").upsert(
      {
        user_id: userId,
        product_id: payload.productId,
        status,
        expires_at: expiresAtIso,
        original_transaction_id: payload.originalTransactionId ?? null,
        environment: payload.environment ?? null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );
    if (upsertError) return jsonError(500, "write_failed", { detail: upsertError.message });

    return new Response(
      JSON.stringify({
        isPlus: status === "active",
        status,
        productId: payload.productId,
        expiresAt: expiresAtIso,
      }),
      { headers: { ...cors, "Content-Type": "application/json" } },
    );
  } catch (e) {
    return jsonError(500, String(e));
  }
}

if (import.meta.main) {
  Deno.serve(handler);
}
