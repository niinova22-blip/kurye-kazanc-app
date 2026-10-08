-- Kurye Kazanc 1.3: yedek upsert'unde (merge-duplicates) updated_at guncellensin.
-- Istemci yalnizca user_id ve payload gonderir; guncelleme zamanini sunucu yazar.
-- Tekrar calistirilabilir.

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists backups_set_updated_at on public.backups;
create trigger backups_set_updated_at
    before update on public.backups
    for each row
    execute function public.set_updated_at();
