-- ============================================================================
-- Tropka — включение Row Level Security
--
-- Запускать целиком в Supabase → SQL Editor. Транзакция: если что-то упадёт,
-- откатится всё, база останется в текущем состоянии.
--
-- Логика доступа:
--   справочники (places, cities, categories, districts, tips, tip_pages)
--       — читают все залогиненные, пишет только service_role (дашборд, скрипты)
--   routes, route_stops
--       — читают все залогиненные, правит только автор маршрута
--   reviews, saved_routes, users
--       — каждый видит и правит только своё
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Триггеры пересчёта. Это обязательный шаг, не косметика.
--
-- update_route_rating висит на reviews и пишет в routes.rating. Без SECURITY
-- DEFINER он выполняется от имени того, кто вставил отзыв — и упирается в
-- политику "правит только автор". Итог: любой отзыв на чужой маршрут падает с
-- ошибкой. Ровно на этом месте обычно и выключают RLS обратно.
--
-- SET search_path заодно закрывает четыре WARN от линтера Supabase.
-- ----------------------------------------------------------------------------

create or replace function public.update_route_rating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_route_id uuid;
begin
  target_route_id := coalesce(new.route_id, old.route_id);

  update public.routes r
  set rating = coalesce((
        select round(avg(rv.rating)::numeric, 2)
        from public.reviews rv
        where rv.route_id = target_route_id
      ), 0),
      review_count = (
        select count(*)
        from public.reviews rv
        where rv.route_id = target_route_id
      )
  where r.id = target_route_id;

  return coalesce(new, old);
end;
$$;

create or replace function public.update_route_duration()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_route_id uuid;
begin
  target_route_id := coalesce(new.route_id, old.route_id);

  update public.routes r
  set duration = coalesce((
        select sum(rs.time_spent)
        from public.route_stops rs
        where rs.route_id = target_route_id
      ), 0)
  where r.id = target_route_id;

  return coalesce(new, old);
end;
$$;

alter function public.handle_new_auth_user() set search_path = public;
alter function public.set_updated_at()      set search_path = public;

-- handle_new_auth_user — триггер на auth.users, снаружи его дёргать незачем
-- anon и authenticated наследуют EXECUTE от PUBLIC, поэтому отзываем именно у PUBLIC
revoke execute on function public.handle_new_auth_user()  from public, anon, authenticated;
revoke execute on function public.update_route_rating()   from public, anon, authenticated;
revoke execute on function public.update_route_duration() from public, anon, authenticated;
revoke execute on function public.set_updated_at()        from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. Включаем RLS на всех таблицах
-- ----------------------------------------------------------------------------

alter table public.users        enable row level security;
alter table public.routes       enable row level security;
alter table public.route_stops  enable row level security;
alter table public.saved_routes enable row level security;
alter table public.reviews      enable row level security;
alter table public.places       enable row level security;
alter table public.cities       enable row level security;
alter table public.categories   enable row level security;
alter table public.districts    enable row level security;
alter table public.tips         enable row level security;
alter table public.tip_pages    enable row level security;

-- ----------------------------------------------------------------------------
-- 3. Справочники — только чтение для залогиненных
--
-- Политик на insert/update/delete нет намеренно: чего нет, то запрещено.
-- Твои скрипты загрузки должны ходить с service_role ключом — он RLS обходит.
-- ----------------------------------------------------------------------------

create policy "places readable"     on public.places     for select to authenticated using (true);
create policy "cities readable"     on public.cities     for select to authenticated using (true);
create policy "categories readable" on public.categories for select to authenticated using (true);
create policy "districts readable"  on public.districts  for select to authenticated using (true);
create policy "tips readable"       on public.tips       for select to authenticated using (true);
create policy "tip_pages readable"  on public.tip_pages  for select to authenticated using (true);

-- ----------------------------------------------------------------------------
-- 4. Маршруты — читают все, правит автор
--
-- Побочный эффект: чинится дыра в RouteEditorService.updateRoute — сейчас он
-- делает update по id без проверки авторства, то есть любой залогиненный
-- пользователь может переписать чужой маршрут. После этих политик не сможет.
-- ----------------------------------------------------------------------------

create policy "routes readable" on public.routes
  for select to authenticated using (true);

create policy "routes insert own" on public.routes
  for insert to authenticated with check (author_uid = auth.uid());

create policy "routes update own" on public.routes
  for update to authenticated using (author_uid = auth.uid())
                                with check (author_uid = auth.uid());

create policy "routes delete own" on public.routes
  for delete to authenticated using (author_uid = auth.uid());

-- ----------------------------------------------------------------------------
-- 5. Остановки — наследуют права родительского маршрута
-- ----------------------------------------------------------------------------

create policy "route_stops readable" on public.route_stops
  for select to authenticated using (true);

create policy "route_stops insert via own route" on public.route_stops
  for insert to authenticated with check (
    exists (select 1 from public.routes r
            where r.id = route_stops.route_id and r.author_uid = auth.uid())
  );

create policy "route_stops update via own route" on public.route_stops
  for update to authenticated using (
    exists (select 1 from public.routes r
            where r.id = route_stops.route_id and r.author_uid = auth.uid())
  );

create policy "route_stops delete via own route" on public.route_stops
  for delete to authenticated using (
    exists (select 1 from public.routes r
            where r.id = route_stops.route_id and r.author_uid = auth.uid())
  );

-- ----------------------------------------------------------------------------
-- 6. Отзывы — читают все залогиненные, правит только автор
--
-- Открыто по решению от 2026-08-17: чужие отзывы должны быть видны на странице
-- маршрута. Внимание: имя автора отзыва пока показать неоткуда — users закрыт
-- политикой "только своя строка". См. комментарий в конце файла.
-- ----------------------------------------------------------------------------

create policy "reviews readable" on public.reviews
  for select to authenticated using (true);

create policy "reviews insert own" on public.reviews
  for insert to authenticated with check (user_id = auth.uid());

create policy "reviews update own" on public.reviews
  for update to authenticated using (user_id = auth.uid())
                                with check (user_id = auth.uid());

create policy "reviews delete own" on public.reviews
  for delete to authenticated using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 7. Сохранённые маршруты — строго приватные
-- ----------------------------------------------------------------------------

create policy "saved_routes select own" on public.saved_routes
  for select to authenticated using (user_id = auth.uid());

create policy "saved_routes insert own" on public.saved_routes
  for insert to authenticated with check (user_id = auth.uid());

create policy "saved_routes update own" on public.saved_routes
  for update to authenticated using (user_id = auth.uid())
                                with check (user_id = auth.uid());

create policy "saved_routes delete own" on public.saved_routes
  for delete to authenticated using (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 8. Профили — только свой
--
-- Строку в users создаёт триггер handle_new_auth_user (SECURITY DEFINER),
-- политика insert нужна для upsert в AuthService.signUp.
-- ----------------------------------------------------------------------------

create policy "users select own" on public.users
  for select to authenticated using (id = auth.uid());

create policy "users insert own" on public.users
  for insert to authenticated with check (id = auth.uid());

create policy "users update own" on public.users
  for update to authenticated using (id = auth.uid())
                                with check (id = auth.uid());

create policy "users delete own" on public.users
  for delete to authenticated using (id = auth.uid());

commit;

-- ============================================================================
-- Проверка после запуска: обе выборки должны вернуть пусто
--
--   select tablename from pg_tables
--   where schemaname = 'public' and rowsecurity = false;
--
--   select tablename from pg_tables t
--   where schemaname = 'public'
--     and not exists (select 1 from pg_policies p
--                     where p.schemaname = 'public' and p.tablename = t.tablename);
-- ============================================================================

-- ============================================================================
-- ПРИМЕНЕНО 2026-08-17. Открытый вопрос на будущее.
--
-- reviews теперь читаются всеми, но public.users закрыт политикой "только своя
-- строка" — значит имя автора чужого отзыва в приложении не отобразится.
--
-- Правильное решение, когда дойдут руки: убрать email из public.users. Он и так
-- лежит в auth.users и доступен клиенту как supabase.auth.currentUser?.email,
-- в публичной таблице профилей ему не место. После этого users становится
-- чисто публичным профилем, и политику select можно смело открыть:
--
--   alter table public.users drop column email;   -- + убрать из AuthService.signUp
--   drop policy "users select own" on public.users;
--   create policy "users readable" on public.users
--     for select to authenticated using (true);
--
-- Пока этого не сделано — открывать users нельзя, утекут email всех юзеров.
-- ============================================================================
