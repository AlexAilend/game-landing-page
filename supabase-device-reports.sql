create extension if not exists pgcrypto;

create table if not exists public.device_reports (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  computer_name text,
  public_ip text,
  os_caption text,
  cpu_name text,
  total_memory_gb numeric,
  report jsonb not null
);

alter table public.device_reports enable row level security;

create index if not exists device_reports_created_at_idx
  on public.device_reports (created_at desc);

create index if not exists device_reports_computer_name_idx
  on public.device_reports (computer_name);
