-- 修正 create_battle_room RPC 多載造成的「Could not choose the best candidate function」錯誤
-- 將舊的 (uuid, uuid, timestamptz, integer, uuid[]) 版本移除，只保留目前使用的 TEXT 版本

DROP FUNCTION IF EXISTS public.create_battle_room(
  uuid,
  uuid,
  timestamptz,
  integer,
  uuid[]
);

