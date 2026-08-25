import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

const SECURE_COOKIE_OPTIONS = {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'lax' as const,
}

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({
    request,
  })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll()
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({
            request,
          })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, {
              ...options,
              ...SECURE_COOKIE_OPTIONS,
            })
          )
        },
      },
    }
  )

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser()

  const path = request.nextUrl.pathname

  const isProtectedPath = path.startsWith('/admin') || path.startsWith('/broker') || path.startsWith('/buyer') || path.startsWith('/seller')
  const isAuthPath = path.startsWith('/login') || path.startsWith('/register')

  // Helper to attach cookies with security flags to redirect responses preserving cookie options
  const createRedirectResponse = (targetUrl: URL) => {
    const redirectResponse = NextResponse.redirect(targetUrl)
    supabaseResponse.cookies.getAll().forEach(cookie => {
      redirectResponse.cookies.set(cookie.name, cookie.value, {
        ...cookie,
        ...SECURE_COOKIE_OPTIONS,
      })
    })
    return redirectResponse
  }

  // Handle unauthenticated or tampered session on protected paths
  if ((authError || !user) && isProtectedPath) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    if (authError) {
      url.searchParams.set('error', 'unauthorized')
    }
    return createRedirectResponse(url)
  }

  if (user) {
    let role = user.user_metadata?.role;
    if (!role) {
      const { data } = await supabase.from('users').select('role').eq('id', user.id).single()
      role = data?.role
    }
    
    if (typeof role === 'string') {
      role = role.toLowerCase()
    }

    // BULLETPROOF FAIL-SAFE: If user is authenticated but has no valid role and tries to access protected areas
    if (!role && isProtectedPath) {
      await supabase.auth.signOut()
      const url = request.nextUrl.clone()
      url.pathname = '/login'
      url.searchParams.set('error', 'unauthorized')
      return createRedirectResponse(url)
    }

    let targetWorkspace = '/'
    if (role === 'admin') targetWorkspace = '/admin'
    else if (role === 'broker') targetWorkspace = '/broker'
    else if (role === 'buyer') targetWorkspace = '/buyer'
    else if (role === 'seller') targetWorkspace = '/seller'
    else targetWorkspace = '/login' // Fallback if no valid role found

    const isAdminPath = path.startsWith('/admin')
    const isBrokerPath = path.startsWith('/broker')
    const isBuyerPath = path.startsWith('/buyer')
    const isSellerPath = path.startsWith('/seller')

    // Root path redirect
    if (path === '/' && targetWorkspace !== '/') {
      const url = request.nextUrl.clone()
      url.pathname = targetWorkspace
      return createRedirectResponse(url)
    }

    // Login and Register pages: If already authenticated with valid role, redirect to workspace
    if (isAuthPath) {
      if (targetWorkspace !== '/login' && targetWorkspace !== path) {
        const url = request.nextUrl.clone()
        url.pathname = targetWorkspace
        return createRedirectResponse(url)
      }
    }

    // Helper for unauthorized role redirection to prevent redirect bouncing
    const redirectToOwnWorkspace = () => {
      const url = request.nextUrl.clone()
      url.pathname = targetWorkspace !== '/login' ? targetWorkspace : '/login'
      url.searchParams.set('error', 'unauthorized_role')
      return createRedirectResponse(url)
    }

    // Role-based protection: Unauthorized access to Admin
    if (isAdminPath && role !== 'admin') {
      return redirectToOwnWorkspace()
    }
    
    // Role-based protection: Unauthorized access to Broker
    if (isBrokerPath && role !== 'broker') {
      return redirectToOwnWorkspace()
    }
    
    // Role-based protection: Trader Workspace access
    const isTrader = role === 'buyer' || role === 'seller'

    if (isBuyerPath && !isTrader) {
      return redirectToOwnWorkspace()
    }

    if (isSellerPath && !isTrader) {
      return redirectToOwnWorkspace()
    }
  }

  return supabaseResponse
}

