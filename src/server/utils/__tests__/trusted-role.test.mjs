// RMBUYER-GST-BACKEND-01 — role-escalation regression tests (audit finding F3).
// Run: node --test src/server/utils/__tests__/trusted-role.test.mjs   (Node 24 strips TS types natively)
import { test } from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { provisionableRole, trustedRole } from '../trusted-role.ts'

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..')
const src = (p) => fs.readFileSync(path.join(repo, p), 'utf8')

test('client user_metadata can never provision a privileged role', () => {
  for (const claimed of ['admin', 'ADMIN', ' admin ', 'broker', 'Broker', 'super_admin', 'service_role', 'adminbuyer']) {
    const role = provisionableRole({ user_metadata: { role: claimed } })
    assert.ok(role === 'buyer' || role === 'seller', `${claimed} -> ${role}`)
    assert.notEqual(role, 'admin')
    assert.notEqual(role, 'broker')
  }
})

test('provisioning never yields a privileged role even from app_metadata', () => {
  // Privileged accounts are created explicitly by an admin, never on first sign-in.
  assert.equal(provisionableRole({ app_metadata: { role: 'admin' } }), 'buyer')
  assert.equal(provisionableRole({ app_metadata: { role: 'broker' }, user_metadata: { role: 'seller' } }), 'seller')
})

test('legitimate buyer and seller sign-up keep their role', () => {
  assert.equal(provisionableRole({ user_metadata: { role: 'buyer' } }), 'buyer')
  assert.equal(provisionableRole({ user_metadata: { role: 'Seller' } }), 'seller')
  assert.equal(provisionableRole({ app_metadata: { role: 'seller' }, user_metadata: { role: 'admin' } }), 'seller')
  assert.equal(provisionableRole({}), 'buyer')
  assert.equal(provisionableRole({ user_metadata: { role: 42 } }), 'buyer')
})

test('trustedRole ignores user_metadata entirely', () => {
  assert.equal(trustedRole({ user_metadata: { role: 'admin' } }), null)
  assert.equal(trustedRole({ user_metadata: { role: 'admin' } }, 'buyer'), 'buyer')
  assert.equal(trustedRole({ app_metadata: { role: 'Admin' }, user_metadata: { role: 'buyer' } }, 'buyer'), 'admin')
  assert.equal(trustedRole({ app_metadata: { role: '' } }, 'seller'), 'seller')
  assert.equal(trustedRole({}, null), null)
})

test('verifyBuyerSession, createCompanyProfile, getCompanyProfile and middleware no longer read user_metadata.role', () => {
  for (const file of ['src/server/utils/buyer-auth.ts', 'src/server/actions/company-actions.ts', 'lib/supabase/middleware.ts']) {
    assert.doesNotMatch(src(file), /user_metadata\??\.role/, `${file} still reads user_metadata.role`)
  }
  assert.match(src('src/server/utils/buyer-auth.ts'), /provisionableRole\(user\)/)
  assert.match(src('src/server/utils/buyer-auth.ts'), /trustedRole\(user, dbUser\.role\) !== 'buyer'/)
  assert.equal((src('src/server/actions/company-actions.ts').match(/provisionableRole\(user\)/g) ?? []).length, 2)
  assert.match(src('lib/supabase/middleware.ts'), /trustedRole\(user\)/)
})

test('requirement sync route requires a Buyer', () => {
  assert.match(src('src/app/api/v1/requirements/sync/route.ts'), /trustedRole\(user, currentUser\[0\]\?\.role\) !== 'buyer'/)
})

test('legacy Company Approvals cannot set is_verified on a Buyer company', () => {
  const s = src('src/server/actions/company-actions.ts')
  assert.match(s, /buyerMember \? \{ status: true \} : \{ status: true, isVerified: true \}/)
})

test('other role-assignment paths are allow-listed (no privileged role from client input)', () => {
  assert.match(src('src/server/actions/auth-actions.ts'), /z\.enum\(\["buyer", "seller"\]\)/)
  assert.match(src('src/lib/validations/broker-directory-schema.ts'), /contactRoleEnum = z\.enum\(\['buyer', 'seller'\]\)/)
  assert.match(src('src/server/actions/admin-user-actions.ts'), /role: "broker"/)
})
