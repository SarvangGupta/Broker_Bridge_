import { useEffect } from 'react';
import { createClient } from '@/lib/supabase/client';
import { useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';

export function useRealtimeDeals() {
  const queryClient = useQueryClient();
  const router = useRouter();

  useEffect(() => {
    const supabase = createClient();
    if (!supabase) {
      return;
    }

    let isSubscribed = true;
    let channel: ReturnType<typeof supabase.channel> | null = null;
    const channelName = `schema-db-changes-${crypto.randomUUID()}`;

    // Setup listener for auth state changes (e.g. token refresh, login, logout)
    const { data: { subscription: authListener } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (!isSubscribed) return;

        if (event === 'TOKEN_REFRESHED' || event === 'SIGNED_IN') {
          if (session?.access_token) {
            try {
              await supabase.realtime.setAuth(session.access_token);
            } catch {
              // Ignore silent auth errors
            }
          }
        } else if (event === 'SIGNED_OUT') {
          if (channel) {
            supabase.removeChannel(channel);
            channel = null;
          }
        }
      }
    );

    async function initRealtimeChannel() {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        
        // If unauthenticated or token is missing, do not attempt to open an unauthorized socket
        if (!session?.access_token) {
          return;
        }

        // Set the active JWT on the realtime connection
        await supabase.realtime.setAuth(session.access_token);

        if (!isSubscribed) return;

        channel = supabase.channel(channelName)
          .on(
            'postgres_changes',
            {
              event: 'INSERT',
              schema: 'public',
              table: 'deals',
            },
            (payload) => {
              queryClient.invalidateQueries({ queryKey: ['deals'] });
              router.refresh();
            }
          )
          .on(
            'postgres_changes',
            {
              event: 'UPDATE',
              schema: 'public',
              table: 'deals',
            },
            (payload) => {
              queryClient.invalidateQueries({ queryKey: ['deals'] });
              router.refresh();
            }
          )
          .on(
            'postgres_changes',
            {
              event: 'UPDATE',
              schema: 'public',
              table: 'quotations',
            },
            (payload) => {
              queryClient.invalidateQueries({ queryKey: ['quotations'] });
              router.refresh();
            }
          )
          .subscribe(async (status, err) => {
            if (status === 'SUBSCRIBED') {
              // Successfully connected
            } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT' || status === 'CLOSED') {
              // If token expired or socket closed abnormally, attempt graceful token refresh
              if (err && typeof err === 'object') {
                const errMsg = (err as any).message || String(err);
                if (errMsg.includes('expired') || errMsg.includes('JWT') || errMsg.includes('token')) {
                  try {
                    const { data: refreshData } = await supabase.auth.refreshSession();
                    if (refreshData?.session?.access_token) {
                      await supabase.realtime.setAuth(refreshData.session.access_token);
                    }
                  } catch {
                    // Session refresh failed, user will be redirected on next action
                  }
                }
              }
            }
          });
      } catch (error) {
        // Suppress uncaught socket initialization errors
      }
    }

    initRealtimeChannel();

    return () => {
      isSubscribed = false;
      authListener?.unsubscribe();
      if (channel) {
        supabase.removeChannel(channel);
      }
    };
  }, [queryClient, router]);
}
