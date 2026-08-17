-- ============================================================================
-- Tropka — вынос email из public.users + закрытие листинга бакетов
-- Применено 2026-08-17, после 20260817_enable_rls.sql
-- ============================================================================

begin;

-- ----------------------------------------------------------------------------
-- 1. Триггер создания профиля больше не копирует email.
--    ВАЖНО: этот шаг обязан идти ПЕРЕД drop column — иначе триггер упадёт
--    на первой же регистрации.
-- ----------------------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, full_name, username, city_id, registration_date)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'username',  split_part(new.email, '@', 1)),
    1,
    now()
  )
  on conflict (id) do nothing;
  return new;
end; $$;

revoke execute on function public.handle_new_auth_user() from public, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. Убираем email. Перед удалением сверено: все 5 строк public.users.email
--    совпадали с auth.users.email — данные не теряются, остаётся первоисточник.
--    В приложении email из этой таблицы не читался нигде.
-- ----------------------------------------------------------------------------

alter table public.users drop column email;

-- ----------------------------------------------------------------------------
-- 3. Профиль больше не содержит ничего приватного — открываем на чтение.
--    Это нужно, чтобы показывать имя автора чужого отзыва.
-- ----------------------------------------------------------------------------

drop policy "users select own" on public.users;

create policy "users readable" on public.users
  for select to authenticated using (true);

-- ----------------------------------------------------------------------------
-- 4. Storage: запрещаем перечисление содержимого бакетов.
--
--    Бакеты помечены public, поэтому прямой доступ к файлу по known URL идёт
--    в обход RLS и продолжит работать. Эти же SELECT-политики давали сверх того
--    право на list — то есть выкачать бакет целиком, не зная имён файлов.
--    Приложению это не нужно: StorageService умеет только upload и getPublicURL.
-- ----------------------------------------------------------------------------

drop policy "Public read avatars" on storage.objects;
drop policy "Public read places"  on storage.objects;
drop policy "Public read routes"  on storage.objects;
drop policy "Public read tips"    on storage.objects;

commit;

-- ============================================================================
-- Сопутствующее изменение в коде: Tropka/Services/AuthService.swift —
-- из struct UserInsert убрано поле email.
--
-- ОТДЕЛЬНО, НЕ ЧАСТЬ ЭТОЙ МИГРАЦИИ:
-- StorageService.swift грузит в бакет "tropka-media", а в проекте существуют
-- только avatars / places / routes / tips. Загрузка обложки маршрута сейчас
-- падает. Либо создать бакет, либо поменять имя в коде.
-- ============================================================================
