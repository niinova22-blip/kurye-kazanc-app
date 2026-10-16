-- 1.13: App Store 5.1.1(v) hesap silme. "Hesabımı sil" sunucudaki verilerle birlikte hesabin kendisini (auth.users) de
-- siler. shifts / calibration_samples / backups auth.users'a "on delete cascade" bagli; acik silmeler yine de durur.
-- Eski surumler ayni fonksiyonu cagirdigi icin onlarda da hesap silinir.
create or replace function public.delete_my_data()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        return;
    end if;
    delete from public.shifts where user_id = uid;
    delete from public.calibration_samples where user_id = uid;
    delete from public.backups where user_id = uid;
    delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_data() from public, anon;
grant execute on function public.delete_my_data() to authenticated;
