/**
 * Trusted role resolution for server code.
 *
 * `user_metadata` is written by the client at sign-up and on every
 * `auth.updateUser()` call, so it can NEVER confer a privileged role.
 * `app_metadata` is server-managed (service role / `trg_sync_privileged_role`)
 * and is the trusted source, mirroring `public.get_auth_role()` in the database.
 *
 * Inserting `public.users.role = 'admin'` is a privilege grant: the
 * `trg_sync_privileged_role` trigger copies it into `app_metadata`, which every
 * RLS policy and `is_admin()` trusts. Self-service provisioning must therefore
 * only ever produce a counterparty role.
 */

type AuthUserLike = {
  app_metadata?: Record<string, unknown> | null
  user_metadata?: Record<string, unknown> | null
}

export const SELF_SERVICE_ROLES = ['buyer', 'seller'] as const
export type SelfServiceRole = (typeof SELF_SERVICE_ROLES)[number]

function normalize(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const role = value.trim().toLowerCase()
  return role.length > 0 ? role : null
}

function isSelfServiceRole(role: string | null): role is SelfServiceRole {
  return role !== null && (SELF_SERVICE_ROLES as readonly string[]).includes(role)
}

/**
 * Role for a `public.users` row created on first sign-in. Only `buyer` or
 * `seller`: privileged accounts (admin, broker) are provisioned explicitly by
 * an admin, never from a session. Defaults to `buyer`.
 */
export function provisionableRole(user: AuthUserLike): SelfServiceRole {
  const trusted = normalize(user.app_metadata?.role)
  if (isSelfServiceRole(trusted)) return trusted
  const claimed = normalize(user.user_metadata?.role)
  if (isSelfServiceRole(claimed)) return claimed
  return 'buyer'
}

/**
 * Role used for routing/authorization decisions: the trusted `app_metadata`
 * role, else the stored `public.users.role`. Never `user_metadata`.
 */
export function trustedRole(user: AuthUserLike, storedRole?: string | null): string | null {
  return normalize(user.app_metadata?.role) ?? normalize(storedRole)
}
