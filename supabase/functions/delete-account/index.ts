// Deletes the calling user's account for real.
//
// The app cannot do this itself: removing a row from auth.users needs the
// service role key, which must never ship inside an iOS binary. The old client
// side version deleted only the public.users profile row, so the auth record
// survived — the same password still signed in, no profile was recreated, and
// the account came back permanently broken. See
// supabase/migrations/20260821c_link_profiles_to_auth_users.sql for the foreign
// key that makes one delete here clean up routes, reviews and saved routes.
//
// A user can only ever delete themselves: the id comes from the verified JWT,
// never from the request body.

import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return json({ error: 'Missing Authorization header' }, 401)
  }

  // Resolve the caller from their own token rather than trusting anything sent.
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  })

  const { data: userData, error: userError } = await caller.auth.getUser()
  if (userError || !userData?.user) {
    return json({ error: 'Not signed in' }, 401)
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  })

  const { error: deleteError } = await admin.auth.admin.deleteUser(userData.user.id)
  if (deleteError) {
    console.error('delete-account failed', userData.user.id, deleteError.message)
    return json({ error: deleteError.message }, 500)
  }

  return json({ deleted: true }, 200)
})
